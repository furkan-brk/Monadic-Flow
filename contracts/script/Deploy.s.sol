// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {EnergyMarket} from "../src/EnergyMarket.sol";

/**
 * @title DeployEnergyMarket
 * @notice Foundry broadcast script that deploys EnergyMarket to Monad testnet.
 * @dev    Reads PRIVATE_KEY from the environment (see .env.example).
 *
 *         Usage:
 *           forge script script/Deploy.s.sol \
 *             --rpc-url https://testnet-rpc.monad.xyz \
 *             --broadcast \
 *             -vvvv
 */
contract DeployEnergyMarket is Script {
    /**
     * @notice Entry point called by `forge script`.
     * @return The address of the newly deployed EnergyMarket contract.
     */
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        EnergyMarket market = new EnergyMarket();

        vm.stopBroadcast();
        return address(market);
    }
}
