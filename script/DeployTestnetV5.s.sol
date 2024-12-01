// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {UnsafeUpgrades} from "../src/upgrades/UnsafeUpgrades.sol";
import {FANtiumNFTV5} from "../src/FANtiumNFTV5.sol";

/**
 * @notice Deploy the FANtiumNFTV5 contract to the testnet.
 */
contract DeployTestnetV5 is Script {
    address public constant ADMIN = 0xF00D14B2bf0b37177b6e13374aB4F34902Eb94fC;

    function run() public {
        vm.startBroadcast();
        FANtiumNFTV5 fantiumNFT = FANtiumNFTV5(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumNFTV5()),
                abi.encodeCall(FANtiumNFTV5.initialize, (ADMIN, "FANtium", "FAN"))
            )
        );
        vm.stopBroadcast();
    }
}
