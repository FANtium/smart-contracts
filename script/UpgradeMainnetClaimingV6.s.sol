// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IAccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Options } from "@openzeppelin/foundry-upgrades/Options.sol";
import { Core } from "@openzeppelin/foundry-upgrades/internal/Core.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { FANtiumClaimingV6 } from "src/FANtiumClaimingV6.sol";

/**
 * @notice Validates and deploys the FANtiumClaimingV6 implementation on Polygon mainnet.
 * @dev V6 retires MANAGER_ROLE (everything it could do is now admin-only), lets the admin fund a distribution on
 *      the athlete's behalf, sends the unclaimed funds of a closed distribution to a new `treasury` instead of
 *      the athlete, and stops burning and re-minting the token on claim. The storage change is a single appended slot
 * (`treasury`), validated against the flattened V5
 *      in `archive/`.
 *
 *      The proxy's DEFAULT_ADMIN_ROLE is held by the FANtium Safe, so this script cannot perform the upgrade
 *      itself. It deploys the implementation and prints the `upgradeToAndCall` transaction the Safe must
 *      execute: the call sets the treasury atomically with the implementation switch, so there is no window in
 *      which `closeDistribution` runs against an unset treasury. Set `CLAIMING_TREASURY` to the treasury address.
 *
 *      It also prints the follow-up transaction revoking the claim proxy's TOKEN_UPGRADER_ROLE on
 *      FANtiumAthletes: V6 no longer renumbers tokens, so the grant is dead weight. Execute it after the upgrade,
 *      never before, or V5 claims revert in the meantime.
 */
contract UpgradeMainnetClaimingV6 is Script {
    error OnlyPolygonMainnet();

    address public constant FANTIUM_CLAIM_PROXY = 0x534db6CE612486F179ef821a57ee93F44718a002;
    address public constant FANTIUM_ATHLETES_PROXY = 0x2b98132E7cfd88C5D854d64f436372838A9BA49d;
    bytes32 public constant TOKEN_UPGRADER_ROLE = keccak256("TOKEN_UPGRADER_ROLE");

    function run() public {
        if (block.chainid != 137) {
            revert OnlyPolygonMainnet();
        }

        address treasury = vm.envAddress("CLAIMING_TREASURY");

        vm.createSelectFork(vm.rpcUrl("polygon"));
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        Options memory opts;
        opts.referenceBuildInfoDir = "out-archive/archive";
        opts.referenceContract = "archive:FANtiumClaimingV5";
        address implementation = Core.prepareUpgrade("FANtiumClaimingV6.sol:FANtiumClaimingV6", opts);
        vm.stopBroadcast();

        console.log("FANtiumClaimingV6 implementation deployed at:", implementation);
        console.log("Treasury:", treasury);
        console.log("Safe transaction to execute:");
        console.log("  to:", FANTIUM_CLAIM_PROXY);
        console.log("  data:");
        console.logBytes(
            abi.encodeCall(
                UUPSUpgradeable.upgradeToAndCall,
                (implementation, abi.encodeCall(FANtiumClaimingV6.setTreasury, (treasury)))
            )
        );

        console.log("Then, once the upgrade is executed:");
        console.log("  to:", FANTIUM_ATHLETES_PROXY);
        console.log("  data:");
        console.logBytes(
            abi.encodeCall(IAccessControlUpgradeable.revokeRole, (TOKEN_UPGRADER_ROLE, FANTIUM_CLAIM_PROXY))
        );
    }
}
