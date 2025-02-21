// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { UnsafeUpgrades, Upgrades } from "@openzeppelin/foundry-upgrades/LegacyUpgrades.sol";
import { Script } from "forge-std/Script.sol"; // v4 contracts
import { FANtiumTokenV1 } from "src/FANtiumTokenV1.sol";
import { FootballTokenV1 } from "src/FootballTokenV1.sol";

/**
 * @notice Deploy a new instance of the FANtiumNFTV6 contract to the testnet.
 */
contract DeployTestnet is Script {
    error OnlyPolygonAmoyTestnet();

    address public constant ADMIN = 0xF00D14B2bf0b37177b6e13374aB4F34902Eb94fC;
    address public constant BACKEND_SIGNER = 0xCAFE914D4886B50edD339eee2BdB5d2350fdC809;
    address public constant DEPLOYER = 0xC0DE5408A46402B7Bd13678A43318c64E2c31EAA;

    bool public FANTIUM_NFT_UPGRADE = true;
    address public constant FANTIUM_NFT_PROXY = 0x4d09f47fd98196CDFC816be9e84Fb15bCDB92612;

    bool public FANTIUM_USER_MANAGER_UPGRADE = false;
    address public constant FANTIUM_USER_MANAGER_PROXY = 0x54dF3fb8B090A3FBf583e29e8fBd388A0179F4A2;

    bool public FANTIUM_CLAIMING_UPGRADE = false;
    address public constant FANTIUM_CLAIMING_PROXY = 0xB578fb2A0BC49892806DC7309Dbe809f23F4682F;

    bool public FANTIUM_TOKEN_UPGRADE = false;
    address public constant FANTIUM_TOKEN_PROXY = 0xd5E5cFf4858AD04D40Cbac54413fADaF8b717914;

    bool public FOOTBALL_TOKEN_UPGRADE = false;
    address public constant FOOTBALL_TOKEN_PROXY = 0x1BDc15D1c0eDfc14E2CD8CE0Ac8a6610bB28f456;

    function run() public {
        if (block.chainid != 80_002) {
            revert OnlyPolygonAmoyTestnet();
        }

        vm.createSelectFork(vm.rpcUrl("amoy"));
        vm.startBroadcast(vm.envUint("ADMIN_PRIVATE_KEY"));
        if (FANTIUM_NFT_UPGRADE) {
            Upgrades.upgradeProxy(FANTIUM_NFT_PROXY, "FANtiumNFTV8.sol:FANtiumNFTV8", "");
        }

        if (FANTIUM_USER_MANAGER_UPGRADE) {
            Upgrades.upgradeProxy(FANTIUM_USER_MANAGER_PROXY, "FANtiumUserManagerV2.sol:FANtiumUserManagerV2", "");
        }

        if (FANTIUM_CLAIMING_UPGRADE) {
            Upgrades.upgradeProxy(FANTIUM_CLAIMING_PROXY, "FANtiumClaimingV2.sol:FANtiumClaimingV2", "");
        }

        if (FANTIUM_TOKEN_UPGRADE) {
            UnsafeUpgrades.upgradeProxy(FANTIUM_TOKEN_PROXY, address(new FANtiumTokenV1()), "");
        }

        if (FOOTBALL_TOKEN_UPGRADE) {
            UnsafeUpgrades.upgradeProxy(FOOTBALL_TOKEN_PROXY, address(new FootballTokenV1()), "");
        }
        vm.stopBroadcast();
    }
}
