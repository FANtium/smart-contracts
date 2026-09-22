// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Options } from "@openzeppelin/foundry-upgrades/Options.sol";
import { Core } from "@openzeppelin/foundry-upgrades/internal/Core.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { PhaseSeedsFixture } from "script/utils/PhaseSeedsFixture.sol";
import { FANtiumAthletesV12 } from "src/FANtiumAthletesV12.sol";
import { PhaseSeed } from "src/interfaces/IFANtiumAthletes.sol";

/**
 * @notice Validates and deploys the FANtiumAthletesV12 implementation on Polygon mainnet.
 * @dev The proxy's DEFAULT_ADMIN_ROLE is held by the FANtium Safe, so this script cannot perform
 *      the upgrade itself. It deploys the implementation and prints the exact `upgradeToAndCall`
 *      transaction the Safe must execute — calling `initializeV12` atomically with the
 *      implementation switch so collections are never live without phases. The phase seeds come
 *      from `test/fixtures/phase-seeds.json`; regenerate it right before broadcasting with
 *      `bun contracts/fantium-v1/scripts/generatePhaseSeeds.ts` so the Strapi schedules are fresh.
 */
contract UpgradeMainnetV12 is Script {
    error OnlyPolygonMainnet();

    address public constant FANTIUM_ATHLETES_PROXY = 0x2b98132E7cfd88C5D854d64f436372838A9BA49d;

    function run() public {
        if (block.chainid != 137) {
            revert OnlyPolygonMainnet();
        }

        vm.createSelectFork(vm.rpcUrl("polygon"));
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        Options memory opts;
        opts.referenceBuildInfoDir = "out-archive/archive";
        opts.referenceContract = "archive:FANtiumAthletesV11";
        address implementation = Core.prepareUpgrade("FANtiumAthletesV12.sol:FANtiumAthletesV12", opts);
        vm.stopBroadcast();

        PhaseSeed[] memory seeds = PhaseSeedsFixture.load(vm);

        console.log("FANtiumAthletesV12 implementation deployed at:", implementation);
        console.log("Phase seeds loaded:", seeds.length);
        console.log("Safe transaction to execute:");
        console.log("  to:", FANTIUM_ATHLETES_PROXY);
        console.log("  data:");
        console.logBytes(
            abi.encodeCall(
                UUPSUpgradeable.upgradeToAndCall,
                (implementation, abi.encodeCall(FANtiumAthletesV12.initializeV12, (seeds)))
            )
        );
    }
}
