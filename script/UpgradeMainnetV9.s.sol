// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Options } from "@openzeppelin/foundry-upgrades/Options.sol";
import { Core } from "@openzeppelin/foundry-upgrades/internal/Core.sol";
import { Script } from "forge-std/Script.sol";

contract UpgradeMainnetV9 is Script {
    error OnlyPolygonMainnet();

    function run() public {
        if (block.chainid != 137) {
            revert OnlyPolygonMainnet();
        }

        vm.createSelectFork(vm.rpcUrl("polygon"));
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        Options memory opts;
        Core.prepareUpgrade("FANtiumAthletesV9.sol:FANtiumAthletesV9", opts);
        Core.prepareUpgrade("FANtiumUserManagerV4.sol:FANtiumUserManagerV4", opts);
        Core.prepareUpgrade("FANtiumClaimingV3.sol:FANtiumClaimingV3", opts);
        vm.stopBroadcast();
    }
}
