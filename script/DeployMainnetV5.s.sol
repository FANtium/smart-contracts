// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Upgrades, Options } from "@openzeppelin/foundry-upgrades/LegacyUpgrades.sol";
import { Script } from "forge-std/Script.sol";
import { FANtiumNFTV5 } from "src/FANtiumNFTV5.sol";

contract DeployMainnetV5 is Script {
    address fantiumNFT_proxy = 0x2b98132E7cfd88C5D854d64f436372838A9BA49d;
    address fantiumNFT_admin = 0x1111111111111111111111111111111111111111;

    function run() public {
        Upgrades.upgradeProxy(
            fantiumNFT_proxy, "FANtiumNFTV5.sol", abi.encodeCall(FANtiumNFTV5.initialize, (fantiumNFT_admin))
        );
    }
}
