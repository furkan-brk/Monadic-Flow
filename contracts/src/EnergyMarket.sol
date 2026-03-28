// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title EnergyMarket
 * @notice Peer-to-peer energy trading contract for the ParallelPulse demo on Monad.
 *         BESS (Battery Energy Storage System) owners post energy offers; the Python
 *         backend (contract owner) settles matched transfers on-chain after the
 *         gsy-e simulation resolves optimal dispatch.
 * @dev    Monad parallel-EVM optimisation: every actor state is stored in its own
 *         top-level mapping (offerAmount, offerPrice, isCriticalLoad, earnings).
 *         Writes from concurrent submitEnergyOffer transactions targeting different
 *         BESS addresses therefore touch non-overlapping storage slots and execute
 *         in parallel without contention.
 *
 *         Emergency mode: activating an emergency multiplies any newly submitted
 *         offer price by EMERGENCY_MULTIPLIER (5x) to reflect real-time scarcity
 *         pricing, mirroring the balancing-market premium in gsy-e.
 */
contract EnergyMarket is Ownable, ReentrancyGuard {
    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @notice Price multiplier applied to all offers while emergencyMode is active.
    uint256 public constant EMERGENCY_MULTIPLIER = 5;

    // -------------------------------------------------------------------------
    // State — split into separate top-level mappings for Monad parallel-EVM
    // -------------------------------------------------------------------------

    /// @notice Whether the market is currently in emergency mode.
    bool public emergencyMode;

    /// @notice The bus ID that triggered the current (or most recent) emergency.
    uint256 public activeBusId;

    /// @notice Available energy in Wh offered by each BESS address.
    mapping(address => uint256) public offerAmount;

    /// @notice Effective offer price in wei per Wh for each BESS address.
    ///         When emergencyMode is active at submission time the stored value
    ///         already incorporates the EMERGENCY_MULTIPLIER.
    mapping(address => uint256) public offerPrice;

    /// @notice Whether an address is registered as a critical load for the
    ///         current emergency period.
    mapping(address => bool) public isCriticalLoad;

    /// @notice Accumulated ETH earnings (in wei) available for each BESS to
    ///         withdraw after settlements.
    mapping(address => uint256) public earnings;

    // -------------------------------------------------------------------------
    // Custom errors — cheaper than require-string reverts
    // -------------------------------------------------------------------------

    /// @notice Thrown when an offer amount of zero is submitted.
    error ZeroOfferAmount();

    /// @notice Thrown when a zero offer price is submitted.
    error ZeroOfferPrice();

    /// @notice Thrown when settleTransfer is called but the BESS has insufficient
    ///         offered energy to cover the requested transfer.
    /// @param bess     The BESS address whose offer was checked.
    /// @param requested The transfer amount that was requested.
    /// @param available The amount actually available in the offer.
    error InsufficientOfferAmount(address bess, uint256 requested, uint256 available);

    /// @notice Thrown when a caller tries to withdraw but has no earnings.
    error NoEarningsToWithdraw();

    /// @notice Thrown when the ETH transfer to the caller fails.
    error WithdrawTransferFailed();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /**
     * @notice Emitted when the owner activates emergency mode for a given bus.
     * @param busId         The grid bus that triggered the emergency.
     * @param criticalLoads The set of load addresses granted priority access.
     * @param timestamp     Block timestamp at activation.
     */
    event EmergencyActivated(
        uint256 indexed busId,
        address[] criticalLoads,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a BESS submits an energy offer.
     * @param bess   The BESS address posting the offer.
     * @param amount Energy offered in Wh.
     * @param price  Effective price in wei per Wh (already multiplied in
     *               emergency mode).
     */
    event EnergyOfferSubmitted(
        address indexed bess,
        uint256 amount,
        uint256 price
    );

    /**
     * @notice Emitted when the owner settles an energy transfer between a BESS
     *         and a load.
     * @param bess   The BESS address delivering energy.
     * @param load   The load address receiving energy.
     * @param amount Energy transferred in Wh.
     * @param cost   Total cost in wei charged to the load (amount * offerPrice).
     */
    event TransferSettled(
        address indexed bess,
        address indexed load,
        uint256 amount,
        uint256 cost
    );

    /**
     * @notice Emitted when the owner deactivates emergency mode.
     * @param busId The bus ID whose emergency has been resolved.
     */
    event EmergencyDeactivated(uint256 indexed busId);

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /// @dev OZ v5 requires the initial owner to be passed explicitly.
    constructor() Ownable(msg.sender) {}

    // -------------------------------------------------------------------------
    // Receive — required so the contract can hold ETH for earnings payouts
    // -------------------------------------------------------------------------

    /// @dev Allows the backend to fund the contract with ETH that is later
    ///      distributed to BESS owners via withdrawEarnings.
    receive() external payable {}

    // -------------------------------------------------------------------------
    // Owner-only: emergency lifecycle
    // -------------------------------------------------------------------------

    /**
     * @notice Activate emergency mode for a specific grid bus.
     * @dev    Sets emergencyMode to true and records which load addresses are
     *         critical for this event.  Emits EmergencyActivated.
     *         Subsequent submitEnergyOffer calls will have their price multiplied
     *         by EMERGENCY_MULTIPLIER until deactivateEmergency is called.
     * @param busId        The grid bus identifier (mirrors gsy-e Area UUID hash).
     * @param criticalLoads Array of consumer addresses that must be served first.
     */
    function activateEmergency(
        uint256 busId,
        address[] calldata criticalLoads
    ) external onlyOwner {
        emergencyMode = true;
        activeBusId = busId;

        uint256 len = criticalLoads.length;
        for (uint256 i = 0; i < len; ) {
            isCriticalLoad[criticalLoads[i]] = true;
            unchecked { ++i; }
        }

        emit EmergencyActivated(busId, criticalLoads, block.timestamp);
    }

    /**
     * @notice Deactivate emergency mode.
     * @dev    Sets emergencyMode to false and emits EmergencyDeactivated.
     *         Does NOT reset isCriticalLoad flags — the owner should call
     *         activateEmergency with an empty array or a new set next time.
     */
    function deactivateEmergency() external onlyOwner {
        emergencyMode = false;
        emit EmergencyDeactivated(activeBusId);
    }

    // -------------------------------------------------------------------------
    // BESS offer submission
    // -------------------------------------------------------------------------

    /**
     * @notice Post an energy offer to the market.
     * @dev    Any BESS address may call this.  When emergencyMode is active the
     *         stored price is price * EMERGENCY_MULTIPLIER, reflecting balancing-
     *         market scarcity pricing from the gsy-e engine.
     *
     *         Monad note: this function only writes to offerAmount[msg.sender]
     *         and offerPrice[msg.sender].  Because each BESS uses a different
     *         key, concurrent calls from N different BESS addresses touch N
     *         distinct storage slots and are parallelisable by Monad's executor.
     *
     * @param amount Energy to offer in Wh.  Must be > 0.
     * @param price  Base price in wei per Wh.  Must be > 0.
     *               If emergencyMode is active the effective stored price will
     *               be price * EMERGENCY_MULTIPLIER.
     */
    function submitEnergyOffer(
        uint256 amount,
        uint256 price
    ) external nonReentrant {
        if (amount == 0) revert ZeroOfferAmount();
        if (price == 0) revert ZeroOfferPrice();

        uint256 effectivePrice = emergencyMode
            ? price * EMERGENCY_MULTIPLIER
            : price;

        offerAmount[msg.sender] = amount;
        offerPrice[msg.sender] = effectivePrice;

        emit EnergyOfferSubmitted(msg.sender, amount, effectivePrice);
    }

    // -------------------------------------------------------------------------
    // Owner-only: settlement
    // -------------------------------------------------------------------------

    /**
     * @notice Settle an energy transfer between a BESS and a load.
     * @dev    Called by the Python backend (owner) after the gsy-e simulation
     *         has determined the optimal dispatch for a time slot.
     *
     *         The cost (amount * offerPrice[bess]) is credited to earnings[bess]
     *         so the BESS owner can withdraw it later.  The contract must hold
     *         sufficient ETH (funded by the backend) to back these earnings.
     *
     *         Reverts with InsufficientOfferAmount if the BESS does not have
     *         enough energy in its current offer to cover the transfer.
     *
     * @param bess   Address of the BESS delivering energy.
     * @param load   Address of the load receiving energy (for event indexing).
     * @param amount Energy to transfer in Wh.
     */
    function settleTransfer(
        address bess,
        address load,
        uint256 amount
    ) external onlyOwner nonReentrant {
        uint256 available = offerAmount[bess];
        if (available < amount) {
            revert InsufficientOfferAmount(bess, amount, available);
        }

        uint256 cost = amount * offerPrice[bess];

        // Decrement offer; use unchecked — underflow guarded by the check above
        unchecked {
            offerAmount[bess] = available - amount;
        }

        earnings[bess] += cost;

        emit TransferSettled(bess, load, amount, cost);
    }

    // -------------------------------------------------------------------------
    // BESS earnings withdrawal
    // -------------------------------------------------------------------------

    /**
     * @notice Withdraw all accumulated ETH earnings to the caller's address.
     * @dev    Uses a checks-effects-interactions pattern: the earnings balance
     *         is zeroed before the ETH transfer to prevent reentrancy even
     *         though ReentrancyGuard is also applied.
     */
    function withdrawEarnings() external nonReentrant {
        uint256 amount = earnings[msg.sender];
        if (amount == 0) revert NoEarningsToWithdraw();

        // Effects before interaction
        earnings[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert WithdrawTransferFailed();
    }
}
