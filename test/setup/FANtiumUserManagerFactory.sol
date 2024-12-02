// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {FANtiumUserManagerV2} from "src/FANtiumUserManagerV2.sol";
import {UnsafeUpgrades} from "src/upgrades/UnsafeUpgrades.sol";
import {BaseTest} from "test/BaseTest.sol";

contract FANtiumUserManagerFactory is BaseTest {
    address public fantiumUserManager_admin = makeAddr("admin");
    address public fantiumUserManager_manager = makeAddr("manager");
    address public fantiumUserManager_forwarder = makeAddr("forwarder");
    address public fantiumUserManager_kycManager = makeAddr("kycManager");
    address public fantiumUserManager_allowlistManager = makeAddr("allowlistManager");

    address public fantiumUserManager_implementation;
    address public fantiumUserManager_proxy;
    FANtiumUserManagerV2 public fantiumUserManager;

    function setUp() public virtual {
        fantiumUserManager_implementation = address(new FANtiumUserManagerV2());
        fantiumUserManager_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumUserManager_implementation,
            abi.encodeCall(FANtiumUserManagerV2.initialize, (fantiumUserManager_admin))
        );
        fantiumUserManager = FANtiumUserManagerV2(fantiumUserManager_proxy);

        vm.startPrank(fantiumUserManager_admin);
        fantiumUserManager.grantRole(fantiumUserManager.MANAGER_ROLE(), fantiumUserManager_manager);
        fantiumUserManager.grantRole(fantiumUserManager.FORWARDER_ROLE(), fantiumUserManager_forwarder);
        fantiumUserManager.grantRole(fantiumUserManager.KYC_MANAGER_ROLE(), fantiumUserManager_kycManager);
        fantiumUserManager.grantRole(fantiumUserManager.ALLOWLIST_MANAGER_ROLE(), fantiumUserManager_allowlistManager);
        vm.stopPrank();
    }
}
