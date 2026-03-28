// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EnergyMarket
 * @notice Decentralised peer-to-peer energy trading contract on Monad.
 *
 * Roles
 * -----
 * - Producer  : registers energy offers (capacity + price per token unit)
 * - Consumer  : requests energy, contract auto-selects the cheapest offer
 * - Battery   : special consumer that monitors its own SOC and self-contracts
 *               when it drops below a configurable threshold
 *
 * Token unit  : 1 MON = 1_000_000_000_000_000_000 wei (18 decimals)
 */
contract EnergyMarket {

    // -----------------------------------------------------------------------
    // Types
    // -----------------------------------------------------------------------

    struct Offer {
        address producer;
        uint256 capacityKwh;     // offered energy (scaled ×100 for 2 decimals)
        uint256 pricePerKwh;     // MON wei per kWh unit
        bool    active;
    }

    struct EnergyContract {
        bytes32 contractId;
        address producer;
        address consumer;
        uint256 amountKwh;
        uint256 pricePerKwh;
        uint256 totalCost;       // pricePerKwh × amountKwh
        uint256 timestamp;
        bool    fulfilled;
    }

    // -----------------------------------------------------------------------
    // Storage
    // -----------------------------------------------------------------------

    mapping(address => Offer) public offers;
    address[] public producerList;

    mapping(bytes32 => EnergyContract) public contracts;
    bytes32[] public contractIds;

    // Battery nodes track their own SOC + threshold on-chain
    mapping(address => uint256) public batterySoc;       // 0-10000 (basis pts)
    mapping(address => uint256) public batteryThreshold;
    mapping(address => uint256) public batteryMaxKwh;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event OfferRegistered(address indexed producer, uint256 capacityKwh, uint256 pricePerKwh);
    event ContractSigned(bytes32 indexed contractId, address producer, address consumer, uint256 amountKwh, uint256 totalCost);
    event ContractRejected(address indexed producer, address indexed consumer, string reason);
    event BatteryThresholdTriggered(address indexed battery, uint256 currentSoc);

    // -----------------------------------------------------------------------
    // Producer API
    // -----------------------------------------------------------------------

    /// Register or update an energy offer.
    function submitOffer(uint256 pricePerKwh, uint256 capacityKwh) external {
        if (!offers[msg.sender].active) {
            producerList.push(msg.sender);
        }
        offers[msg.sender] = Offer({
            producer: msg.sender,
            capacityKwh: capacityKwh,
            pricePerKwh: pricePerKwh,
            active: true
        });
        emit OfferRegistered(msg.sender, capacityKwh, pricePerKwh);
    }

    // -----------------------------------------------------------------------
    // Consumer API — Scenario 1 & 2
    // -----------------------------------------------------------------------

    /**
     * @notice Request `amountKwh` of energy.
     *         Scenario 1: single cheapest producer covers full demand.
     *         Scenario 2: if cheapest cannot cover full demand, remainder is
     *                     filled from the next cheapest producer.
     * @return totalCost  Total MON wei charged to the caller.
     */
    function requestEnergy(uint256 amountKwh)
        external
        payable
        returns (uint256 totalCost)
    {
        uint256 remaining = amountKwh;

        // Sort producers by price (off-chain indexing in practice; simplified here)
        address cheapest = _findCheapest(remaining);

        while (remaining > 0 && cheapest != address(0)) {
            Offer storage offer = offers[cheapest];
            uint256 fill = remaining < offer.capacityKwh
                ? remaining
                : offer.capacityKwh;

            uint256 cost = fill * offer.pricePerKwh;
            totalCost += cost;
            offer.capacityKwh -= fill;
            remaining -= fill;

            bytes32 cid = _mintContract(cheapest, msg.sender, fill, offer.pricePerKwh, cost);
            emit ContractSigned(cid, cheapest, msg.sender, fill, cost);

            cheapest = remaining > 0 ? _findCheapest(remaining) : address(0);
        }

        if (remaining > 0) {
            emit ContractRejected(address(0), msg.sender, "Insufficient supply");
        }
    }

    /// Returns the cheapest active producer that has at least some capacity.
    function evaluateBestOffer(uint256 /*amountKwh*/)
        external
        view
        returns (address bestProducer, uint256 bestPrice)
    {
        for (uint i = 0; i < producerList.length; i++) {
            Offer storage o = offers[producerList[i]];
            if (o.active && o.capacityKwh > 0) {
                if (bestProducer == address(0) || o.pricePerKwh < bestPrice) {
                    bestProducer = o.producer;
                    bestPrice    = o.pricePerKwh;
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Battery API — Scenario 3
    // -----------------------------------------------------------------------

    /// Battery node registers its parameters.
    function registerBattery(
        uint256 maxKwh,
        uint256 thresholdBps   // e.g. 3000 = 30.00 %
    ) external {
        batteryMaxKwh[msg.sender]     = maxKwh;
        batteryThreshold[msg.sender]  = thresholdBps;
        batterySoc[msg.sender]        = 8000; // start at 80 %
    }

    /**
     * @notice Called periodically (or by Monad keeper).
     *         If SOC < threshold, auto-contracts energy up to 80 % SOC.
     */
    function chargeBattery() external payable {
        uint256 soc = batterySoc[msg.sender];
        uint256 threshold = batteryThreshold[msg.sender];

        require(soc < threshold, "SOC above threshold");
        emit BatteryThresholdTriggered(msg.sender, soc);

        uint256 deficitBps = 8000 - soc;                        // target 80 %
        uint256 neededKwh  = (deficitBps * batteryMaxKwh[msg.sender]) / 10000;

        // Reuse requestEnergy logic — battery IS the consumer
        uint256 remaining = neededKwh;
        address cheapest  = _findCheapest(remaining);

        while (remaining > 0 && cheapest != address(0)) {
            Offer storage offer = offers[cheapest];
            uint256 fill = remaining < offer.capacityKwh
                ? remaining
                : offer.capacityKwh;

            uint256 cost = fill * offer.pricePerKwh;
            offer.capacityKwh -= fill;
            remaining -= fill;

            bytes32 cid = _mintContract(cheapest, msg.sender, fill, offer.pricePerKwh, cost);
            emit ContractSigned(cid, cheapest, msg.sender, fill, cost);

            cheapest = remaining > 0 ? _findCheapest(remaining) : address(0);
        }

        // Update SOC proportionally
        uint256 chargedBps = ((neededKwh - remaining) * 10000) / batteryMaxKwh[msg.sender];
        batterySoc[msg.sender] = soc + chargedBps;
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    function _findCheapest(uint256 /*need*/) internal view returns (address best) {
        uint256 bestPrice = type(uint256).max;
        for (uint i = 0; i < producerList.length; i++) {
            Offer storage o = offers[producerList[i]];
            if (o.active && o.capacityKwh > 0 && o.pricePerKwh < bestPrice) {
                best      = o.producer;
                bestPrice = o.pricePerKwh;
            }
        }
    }

    function _mintContract(
        address producer,
        address consumer,
        uint256 amountKwh,
        uint256 price,
        uint256 cost
    ) internal returns (bytes32 cid) {
        cid = keccak256(abi.encodePacked(producer, consumer, amountKwh, block.timestamp, contractIds.length));
        contracts[cid] = EnergyContract({
            contractId: cid,
            producer:   producer,
            consumer:   consumer,
            amountKwh:  amountKwh,
            pricePerKwh: price,
            totalCost:  cost,
            timestamp:  block.timestamp,
            fulfilled:  false
        });
        contractIds.push(cid);
    }
}
