// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;
// Scripts are expected to print their results.
// solhint-disable no-console

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Options } from "@openzeppelin/foundry-upgrades/Options.sol";
import { Core } from "@openzeppelin/foundry-upgrades/internal/Core.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

/**
 * @notice Validates and deploys a fresh FANtiumClaimingV5 implementation on Polygon mainnet.
 * @dev The Solidity source is unchanged: this redeploy only recompiles it against the FANtiumAthletesV12
 *      `Collection` struct. V12 added `PricePhase[] phases`, which made `collections()` return a dynamic
 *      tuple; the previous claim implementation still decodes the static V11 layout, so every path that reads
 *      a collection (`createDistribution`, `updateDistribution`, `recomputeShares`) reverts with empty data.
 *
 *      The proxy's DEFAULT_ADMIN_ROLE is held by the FANtium Safe, so this script cannot perform the upgrade
 *      itself. It deploys the implementation and prints the exact `upgradeTo` transaction the Safe must
 *      execute. `upgradeToAndCall` with empty data is not an option: OpenZeppelin 4.9 force-calls the new
 *      implementation, which hits the missing fallback and reverts.
 */
contract UpgradeMainnetClaimingV5 is Script {
    error OnlyPolygonMainnet();

    address public constant FANTIUM_CLAIM_PROXY = 0x534db6CE612486F179ef821a57ee93F44718a002;

    function run() public {
        if (block.chainid != 137) {
            revert OnlyPolygonMainnet();
        }

        vm.createSelectFork(vm.rpcUrl("polygon"));
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        Options memory opts;
        opts.referenceBuildInfoDir = "out-archive/archive";
        opts.referenceContract = "archive:FANtiumClaimingV4";
        address implementation = Core.prepareUpgrade("FANtiumClaimingV5.sol:FANtiumClaimingV5", opts);
        vm.stopBroadcast();

        console.log("FANtiumClaimingV5 implementation deployed at:", implementation);
        console.log("Safe transaction to execute:");
        console.log("  to:", FANTIUM_CLAIM_PROXY);
        console.log("  data:");
        console.logBytes(abi.encodeCall(UUPSUpgradeable.upgradeTo, (implementation)));
    }
}
