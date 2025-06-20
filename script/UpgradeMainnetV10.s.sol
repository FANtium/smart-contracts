// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Options } from "@openzeppelin/foundry-upgrades/Options.sol";
import { Core } from "@openzeppelin/foundry-upgrades/internal/Core.sol";
import { Script } from "forge-std/Script.sol";

contract UpgradeMainnetV10 is Script {
    error OnlyPolygonMainnet();

    function run() public {
        if (block.chainid != 137) {
            revert OnlyPolygonMainnet();
        }

        vm.createSelectFork(vm.rpcUrl("polygon"));
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        Options memory opts;
        Core.prepareUpgrade("FANtiumAthletesV10.sol:FANtiumAthletesV10", opts);
        Core.prepareUpgrade("FANtiumClaimingV5.sol:FANtiumClaimingV5", opts);
        vm.stopBroadcast();
    }
}
