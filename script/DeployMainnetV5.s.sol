// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Upgrades } from "@openzeppelin/foundry-upgrades/LegacyUpgrades.sol";
import { Script } from "forge-std/Script.sol";
import { FANtiumNFTV5 } from "src/FANtiumNFTV5.sol";

contract DeployMainnetV5 is Script {
    address private constant FANTIUM_NFT_PROXY = 0x2b98132E7cfd88C5D854d64f436372838A9BA49d;
    address private constant FANTIUM_NFT_ADMIN = 0x1111111111111111111111111111111111111111;

    function run() public {
        Upgrades.upgradeProxy(
            FANTIUM_NFT_PROXY, "FANtiumNFTV5.sol", abi.encodeCall(FANtiumNFTV5.initialize, (FANTIUM_NFT_ADMIN))
        );
    }
}
