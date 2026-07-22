// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Upgrades } from "@openzeppelin/foundry-upgrades/LegacyUpgrades.sol";
import { Options } from "@openzeppelin/foundry-upgrades/Options.sol";
import { Script } from "forge-std/Script.sol"; // v4 contracts
import { FANtiumAthletesV12 } from "src/FANtiumAthletesV12.sol";
import { PhaseSeed } from "src/interfaces/IFANtiumAthletes.sol";

/**
 * @notice Deploy a new version of our contracts to the testnet.
 */
contract UpgradeTestnet is Script {
    error OnlyPolygonAmoyTestnet();

    address public constant ADMIN = 0xF00D14B2bf0b37177b6e13374aB4F34902Eb94fC;
    address public constant BACKEND_SIGNER = 0xCAFE914D4886B50edD339eee2BdB5d2350fdC809;
    address public constant DEPLOYER = 0xC0DE5408A46402B7Bd13678A43318c64E2c31EAA;

    bool public FANTIUM_ATHLETES_UPGRADE = true;
    address public constant FANTIUM_ATHLETES_PROXY = 0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612;

    bool public FANTIUM_CLAIMING_UPGRADE = false;
    address public constant FANTIUM_CLAIMING_PROXY = 0xB578fb2A0BC49892806DC7309Dbe809f23F4682F;

    function run() public {
        if (block.chainid != 80_002) {
            revert OnlyPolygonAmoyTestnet();
        }

        vm.createSelectFork(vm.rpcUrl("amoy"));
        vm.startBroadcast(vm.envUint("ADMIN_PRIVATE_KEY"));

        Options memory opts;
        opts.referenceBuildInfoDir = "out-archive/archive";

        if (FANTIUM_ATHLETES_UPGRADE) {
            // upgradeToAndCall: run the V12 storage migration atomically with the implementation switch.
            // No phase seeds on testnet — every collection gets the single-phase default migration.
            PhaseSeed[] memory seeds = new PhaseSeed[](0);
            Upgrades.upgradeProxy(
                FANTIUM_ATHLETES_PROXY,
                "FANtiumAthletesV12.sol:FANtiumAthletesV12",
                abi.encodeCall(FANtiumAthletesV12.initializeV12, (seeds)),
                opts
            );
        }

        if (FANTIUM_CLAIMING_UPGRADE) {
            Upgrades.upgradeProxy(FANTIUM_CLAIMING_PROXY, "FANtiumClaimingV5.sol:FANtiumClaimingV5", "", opts);
        }
        vm.stopBroadcast();
    }
}
