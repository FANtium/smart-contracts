// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {FANtiumNFTFactory} from "./FANtiumNFTFactory.sol";
import {BaseTest} from "../BaseTest.sol";

contract FANtiumNFTFactoryTest is BaseTest, FANtiumNFTFactory {
    function test_setUp_ok() public {
        assertEq(fantiumNFT.fantiumUserManager(), fantiumUserManager_proxy);
    }
}
