// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { FANtiumNFTFactory } from "test/setup/FANtiumNFTFactory.sol";
import { BaseTest } from "test/BaseTest.sol";

contract FANtiumNFTFactoryTest is BaseTest, FANtiumNFTFactory {
    function test_setUp_ok() public view {
        assertEq(fantiumNFT.fantiumUserManager(), fantiumUserManager_proxy);
    }
}
