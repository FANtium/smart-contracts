// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseTest } from "test/BaseTest.sol";
import { FANtiumAthletesFactory } from "test/setup/FANtiumAthletesFactory.sol";

contract FANtiumAthletesFactoryTest is BaseTest, FANtiumAthletesFactory {
    function test_setUp_ok() public view {
        assertEq(address(fantiumAthletes.userManager()), userManager_proxy);
        assertEq(address(fantiumAthletes.erc20PaymentToken()), address(usdc));
    }
}
