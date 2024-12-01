// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {FANtiumUserManager} from "../../src/FANtiumUserManagerV2.sol";
import {UnsafeUpgrades} from "../../src/upgrades/UnsafeUpgrades.sol";
import {BaseTest} from "../BaseTest.sol";

contract FANtiumUserManagerFactory is BaseTest {
    address public admin = makeAddr("admin");

    address public fantiumUserManager_implementation;
    address public fantiumUserManager_proxy;
    FANtiumUserManagerV2 public fantiumUserManager;

    function setUp() public virtual {
        fantiumUserManager_implementation = address(new FANtiumUserManager());
        fantiumUserManager_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumUserManager_implementation,
            abi.encodeCall(FANtiumUserManager.initialize, (admin))
        );
        fantiumUserManager = FANtiumUserManager(fantiumUserManager_proxy);
    }
}
