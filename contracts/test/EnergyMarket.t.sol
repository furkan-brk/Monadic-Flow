// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EnergyMarket} from "../src/EnergyMarket.sol";

/**
 * @title EnergyMarketTest
 * @notice Foundry test suite for EnergyMarket.sol.
 * @dev    Run with: forge test -vv
 */
contract EnergyMarketTest is Test {
    // -------------------------------------------------------------------------
    // Event mirrors (required for vm.expectEmit — Solidity cannot reference
    // events from an external contract type directly)
    // -------------------------------------------------------------------------

    event EmergencyActivated(uint256 indexed busId, address[] criticalLoads, uint256 timestamp);
    event EnergyOfferSubmitted(address indexed bess, uint256 amount, uint256 price);
    event TransferSettled(address indexed bess, address indexed load, uint256 amount, uint256 cost);
    event EmergencyDeactivated(uint256 indexed busId);

    // -------------------------------------------------------------------------
    // Fixtures
    // -------------------------------------------------------------------------

    EnergyMarket internal market;

    address internal owner = makeAddr("owner");
    address internal bess1  = makeAddr("bess1");
    address internal bess2  = makeAddr("bess2");
    address internal load1  = makeAddr("load1");
    address internal load2  = makeAddr("load2");
    address internal attacker = makeAddr("attacker");

    uint256 internal constant OFFER_AMOUNT = 1000; // Wh
    uint256 internal constant OFFER_PRICE  = 1e15; // 0.001 ETH per Wh
    uint256 internal constant BUS_ID       = 42;

    // -------------------------------------------------------------------------
    // Setup
    // -------------------------------------------------------------------------

    function setUp() public {
        // Deploy from the designated owner account
        vm.prank(owner);
        market = new EnergyMarket();

        // Fund the contract so it can pay out earnings
        vm.deal(address(market), 100 ether);
        // Give BESS accounts some ETH for gas
        vm.deal(bess1, 1 ether);
        vm.deal(bess2, 1 ether);
    }

    // -------------------------------------------------------------------------
    // Helper: build a simple criticalLoads array
    // -------------------------------------------------------------------------

    function _criticalLoads() internal view returns (address[] memory loads) {
        loads = new address[](2);
        loads[0] = load1;
        loads[1] = load2;
    }

    // -------------------------------------------------------------------------
    // activateEmergency
    // -------------------------------------------------------------------------

    /**
     * @notice Owner activates emergency; emergencyMode must be true, critical
     *         load flags must be set, and the event must be emitted.
     */
    function test_ActivateEmergency() public {
        address[] memory loads = _criticalLoads();

        // Declare all four topics + data check
        vm.expectEmit(true, false, false, true, address(market));
        emit EmergencyActivated(BUS_ID, loads, block.timestamp);

        vm.prank(owner);
        market.activateEmergency(BUS_ID, loads);

        assertTrue(market.emergencyMode(), "emergencyMode should be true");
        assertEq(market.activeBusId(), BUS_ID, "activeBusId mismatch");
        assertTrue(market.isCriticalLoad(load1), "load1 should be critical");
        assertTrue(market.isCriticalLoad(load2), "load2 should be critical");
        assertFalse(market.isCriticalLoad(attacker), "attacker should NOT be critical");
    }

    /**
     * @notice Non-owner caller must be reverted with OwnableUnauthorizedAccount.
     */
    function test_ActivateEmergencyNotOwner() public {
        address[] memory loads = _criticalLoads();

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                attacker
            )
        );
        market.activateEmergency(BUS_ID, loads);
    }

    // -------------------------------------------------------------------------
    // submitEnergyOffer — normal mode
    // -------------------------------------------------------------------------

    /**
     * @notice In normal mode the stored price equals the submitted price exactly.
     */
    function test_SubmitOfferNormalMode() public {
        vm.expectEmit(true, false, false, true, address(market));
        emit EnergyOfferSubmitted(bess1, OFFER_AMOUNT, OFFER_PRICE);

        vm.prank(bess1);
        market.submitEnergyOffer(OFFER_AMOUNT, OFFER_PRICE);

        assertEq(market.offerAmount(bess1), OFFER_AMOUNT, "offerAmount mismatch");
        assertEq(market.offerPrice(bess1), OFFER_PRICE, "offerPrice should be unchanged in normal mode");
    }

    /**
     * @notice In emergency mode the stored price must be input * EMERGENCY_MULTIPLIER.
     */
    function test_SubmitOfferEmergencyMode5x() public {
        // Activate emergency first
        vm.prank(owner);
        market.activateEmergency(BUS_ID, new address[](0));

        uint256 expectedPrice = OFFER_PRICE * market.EMERGENCY_MULTIPLIER();

        vm.expectEmit(true, false, false, true, address(market));
        emit EnergyOfferSubmitted(bess1, OFFER_AMOUNT, expectedPrice);

        vm.prank(bess1);
        market.submitEnergyOffer(OFFER_AMOUNT, OFFER_PRICE);

        assertEq(market.offerPrice(bess1), expectedPrice, "price must be 5x in emergency mode");
    }

    /**
     * @notice Submitting a zero amount must revert with ZeroOfferAmount.
     */
    function test_SubmitOfferZeroAmount() public {
        vm.prank(bess1);
        vm.expectRevert(EnergyMarket.ZeroOfferAmount.selector);
        market.submitEnergyOffer(0, OFFER_PRICE);
    }

    /**
     * @notice Submitting a zero price must revert with ZeroOfferPrice.
     */
    function test_SubmitOfferZeroPrice() public {
        vm.prank(bess1);
        vm.expectRevert(EnergyMarket.ZeroOfferPrice.selector);
        market.submitEnergyOffer(OFFER_AMOUNT, 0);
    }

    // -------------------------------------------------------------------------
    // settleTransfer
    // -------------------------------------------------------------------------

    /**
     * @notice Full happy-path: activate, submit, settle; check offerAmount
     *         decremented and earnings credited.
     */
    function test_SettleTransfer() public {
        // Activate emergency and submit offer
        vm.prank(owner);
        market.activateEmergency(BUS_ID, _criticalLoads());

        vm.prank(bess1);
        market.submitEnergyOffer(OFFER_AMOUNT, OFFER_PRICE);

        uint256 transferAmount = 400; // Wh
        uint256 effectivePrice = OFFER_PRICE * market.EMERGENCY_MULTIPLIER();
        uint256 expectedCost   = transferAmount * effectivePrice;

        vm.expectEmit(true, true, false, true, address(market));
        emit TransferSettled(bess1, load1, transferAmount, expectedCost);

        vm.prank(owner);
        market.settleTransfer(bess1, load1, transferAmount);

        assertEq(
            market.offerAmount(bess1),
            OFFER_AMOUNT - transferAmount,
            "offerAmount must decrease by transfer amount"
        );
        assertEq(
            market.earnings(bess1),
            expectedCost,
            "earnings must equal cost of transfer"
        );
    }

    /**
     * @notice Attempting to settle more energy than the BESS has offered must
     *         revert with InsufficientOfferAmount.
     */
    function test_SettleTransferInsufficientAmount() public {
        vm.prank(bess1);
        market.submitEnergyOffer(OFFER_AMOUNT, OFFER_PRICE);

        uint256 tooMuch = OFFER_AMOUNT + 1;

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                EnergyMarket.InsufficientOfferAmount.selector,
                bess1,
                tooMuch,
                OFFER_AMOUNT
            )
        );
        market.settleTransfer(bess1, load1, tooMuch);
    }

    /**
     * @notice Non-owner calling settleTransfer must revert.
     */
    function test_SettleTransferNotOwner() public {
        vm.prank(bess1);
        market.submitEnergyOffer(OFFER_AMOUNT, OFFER_PRICE);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                attacker
            )
        );
        market.settleTransfer(bess1, load1, 100);
    }

    // -------------------------------------------------------------------------
    // withdrawEarnings
    // -------------------------------------------------------------------------

    /**
     * @notice After a settlement the BESS owner withdraws their ETH earnings.
     *         Balance must increase by exactly the earnings amount.
     */
    function test_WithdrawEarnings() public {
        // Submit offer and settle
        vm.prank(bess1);
        market.submitEnergyOffer(OFFER_AMOUNT, OFFER_PRICE);

        uint256 transferAmount = OFFER_AMOUNT;
        uint256 expectedCost   = transferAmount * OFFER_PRICE;

        vm.prank(owner);
        market.settleTransfer(bess1, load1, transferAmount);

        assertEq(market.earnings(bess1), expectedCost, "pre-withdraw earnings mismatch");

        uint256 balanceBefore = bess1.balance;

        vm.prank(bess1);
        market.withdrawEarnings();

        uint256 balanceAfter = bess1.balance;

        assertEq(
            balanceAfter - balanceBefore,
            expectedCost,
            "ETH received must equal earnings"
        );
        assertEq(market.earnings(bess1), 0, "earnings must be zero after withdrawal");
    }

    /**
     * @notice Withdrawing with zero earnings must revert with NoEarningsToWithdraw.
     */
    function test_WithdrawEarningsZeroBalance() public {
        vm.prank(bess1);
        vm.expectRevert(EnergyMarket.NoEarningsToWithdraw.selector);
        market.withdrawEarnings();
    }

    // -------------------------------------------------------------------------
    // deactivateEmergency
    // -------------------------------------------------------------------------

    /**
     * @notice Owner deactivates emergency; emergencyMode must become false and
     *         EmergencyDeactivated must be emitted.
     */
    function test_DeactivateEmergency() public {
        vm.prank(owner);
        market.activateEmergency(BUS_ID, new address[](0));

        assertTrue(market.emergencyMode(), "should be in emergency before deactivation");

        vm.expectEmit(true, false, false, false, address(market));
        emit EmergencyDeactivated(BUS_ID);

        vm.prank(owner);
        market.deactivateEmergency();

        assertFalse(market.emergencyMode(), "emergencyMode must be false after deactivation");
    }

    /**
     * @notice After deactivation, a new offer should be stored at base price (no
     *         multiplier), even if emergency was active for a previous offer.
     */
    function test_OfferPriceResetsAfterDeactivation() public {
        // Activate, then immediately deactivate
        vm.prank(owner);
        market.activateEmergency(BUS_ID, new address[](0));

        vm.prank(owner);
        market.deactivateEmergency();

        vm.prank(bess1);
        market.submitEnergyOffer(OFFER_AMOUNT, OFFER_PRICE);

        assertEq(
            market.offerPrice(bess1),
            OFFER_PRICE,
            "price must not be multiplied after deactivation"
        );
    }

    // -------------------------------------------------------------------------
    // Parallel-EVM: independent BESS addresses do not interfere
    // -------------------------------------------------------------------------

    /**
     * @notice Two BESS addresses submit offers independently; each must store
     *         their own amount and price without overwriting the other.
     */
    function test_ParallelOfferIsolation() public {
        uint256 amount2 = 500;
        uint256 price2  = 2e15;

        vm.prank(bess1);
        market.submitEnergyOffer(OFFER_AMOUNT, OFFER_PRICE);

        vm.prank(bess2);
        market.submitEnergyOffer(amount2, price2);

        assertEq(market.offerAmount(bess1), OFFER_AMOUNT, "bess1 amount corrupted");
        assertEq(market.offerPrice(bess1),  OFFER_PRICE,  "bess1 price corrupted");
        assertEq(market.offerAmount(bess2), amount2,       "bess2 amount corrupted");
        assertEq(market.offerPrice(bess2),  price2,        "bess2 price corrupted");
    }

    // -------------------------------------------------------------------------
    // receive() — contract must accept ETH
    // -------------------------------------------------------------------------

    /**
     * @notice The contract must accept a plain ETH transfer via receive().
     */
    function test_ReceiveEther() public {
        uint256 balanceBefore = address(market).balance;
        (bool ok, ) = address(market).call{value: 1 ether}("");
        assertTrue(ok, "ETH transfer to contract failed");
        assertEq(address(market).balance, balanceBefore + 1 ether, "contract balance mismatch");
    }
}
