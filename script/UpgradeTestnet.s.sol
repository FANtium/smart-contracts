// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { Upgrades } from "@openzeppelin/foundry-upgrades/LegacyUpgrades.sol";

/**
 * @notice Deploy a new instance of the FANtiumNFTV6 contract to the testnet.
 */
contract DeployTestnetV5 is Script {
    address public constant ADMIN = 0xF00D14B2bf0b37177b6e13374aB4F34902Eb94fC;
    address public constant BACKEND_SIGNER = 0xCAFE914D4886B50edD339eee2BdB5d2350fdC809;
    address public constant DEPLOYER = 0xC0DE5408A46402B7Bd13678A43318c64E2c31EAA;

    bool public FANTIUM_NFT_UPGRADE = false;
    address public constant FANTIUM_NFT_PROXY = 0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612;
    bool public FANTIUM_USER_MANAGER_UPGRADE = false;
    address public constant FANTIUM_USER_MANAGER_PROXY = 0x54dF3fb8B090A3FBf583e29e8fBd388A0179F4A2;
    bool public FANTIUM_CLAIMING_UPGRADE = true;
    address public constant FANTIUM_CLAIMING_PROXY = 0xB578fb2A0BC49892806DC7309Dbe809f23F4682F;

    function run() public {
        vm.startBroadcast(vm.envUint("ADMIN_PRIVATE_KEY"));
        if (FANTIUM_NFT_UPGRADE) {
            Upgrades.upgradeProxy(FANTIUM_NFT_PROXY, "FANtiumNFTV6.sol:FANtiumNFTV6", "");
        }

        if (FANTIUM_USER_MANAGER_UPGRADE) {
            Upgrades.upgradeProxy(FANTIUM_USER_MANAGER_PROXY, "FANtiumUserManagerV2.sol:FANtiumUserManagerV2", "");
        }

        if (FANTIUM_CLAIMING_UPGRADE) {
            Upgrades.upgradeProxy(FANTIUM_CLAIMING_PROXY, "FANtiumClaimingV2.sol:FANtiumClaimingV2", "");
        }
        vm.stopBroadcast();
    }
}
