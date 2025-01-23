// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseTest } from "test/BaseTest.sol";
import {FANtiumTokenV1} from "../../src/FANtiumTokenV1.sol";
import { UnsafeUpgrades } from "../../src/upgrades/UnsafeUpgrades.sol";

contract FANtiumTokenFactory is BaseTest {
    address public fantiumToken_admin = makeAddr("admin");

    address public fantiumToken_implementation;
    address public fantiumToken_proxy;
    FANtiumTokenV1 public fantiumToken;

    function setUp() public virtual {
        fantiumToken_implementation = address(new FANtiumTokenV1());

        fantiumToken_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumToken_implementation, abi.encodeCall(FANtiumTokenV1.initialize, (fantiumToken_admin))
        );

        fantiumToken = FANtiumTokenV1(fantiumToken_proxy);
    }
}
