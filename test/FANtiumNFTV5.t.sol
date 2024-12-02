// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseTest } from "test/BaseTest.sol";
import { FANtiumNFTV5 } from "src/FANtiumNFTV5.sol";
import { IFANtiumNFT, Collection, CreateCollection } from "src/interfaces/IFANtiumNFT.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { FANtiumNFTFactory } from "test/setup/FANtiumNFTFactory.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract FANtiumNFTV5Test is BaseTest, FANtiumNFTFactory {
    function setUp() public override {
        FANtiumNFTFactory.setUp();
    }

    // version
    // ========================================================================
    function test_version() public view {
        assertEq(fantiumNFT.version(), "5.0.0");
    }

    // name
    // ========================================================================
    function test_name() public view {
        assertEq(fantiumNFT.name(), "FANtium");
    }

    // symbol
    // ========================================================================
    function test_symbol() public view {
        assertEq(fantiumNFT.symbol(), "FAN");
    }
}
