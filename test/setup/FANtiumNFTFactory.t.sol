// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseTest } from "test/BaseTest.sol";
import { FANtiumNFTFactory } from "test/setup/FANtiumNFTFactory.sol";

contract FANtiumNFTFactoryTest is BaseTest, FANtiumNFTFactory {
    function test_setUp_ok() public view {
        assertEq(address(fantiumNFT.userManager()), userManager_proxy);
        assertEq(address(fantiumNFT.erc20PaymentToken()), address(usdc));
    }
}
