// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { FANtiumUserManagerV2 } from "src/FANtiumUserManagerV2.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "test/BaseTest.sol";

contract FANtiumUserManagerFactory is BaseTest {
    address public userManager_admin = makeAddr("admin");
    address public userManager_manager = makeAddr("manager");
    address public userManager_forwarder = makeAddr("forwarder");
    address public userManager_kycManager = makeAddr("kycManager");
    address public userManager_allowlistManager = makeAddr("allowlistManager");

    address public userManager_implementation;
    address public userManager_proxy;
    FANtiumUserManagerV2 public userManager;

    function setUp() public virtual {
        userManager_implementation = address(new FANtiumUserManagerV2());
        userManager_proxy = UnsafeUpgrades.deployUUPSProxy(
            userManager_implementation, abi.encodeCall(FANtiumUserManagerV2.initialize, (userManager_admin))
        );
        userManager = FANtiumUserManagerV2(userManager_proxy);

        vm.startPrank(userManager_admin);
        userManager.grantRole(userManager.MANAGER_ROLE(), userManager_manager);
        userManager.grantRole(userManager.FORWARDER_ROLE(), userManager_forwarder);
        userManager.grantRole(userManager.KYC_MANAGER_ROLE(), userManager_kycManager);
        userManager.grantRole(userManager.ALLOWLIST_MANAGER_ROLE(), userManager_allowlistManager);
        vm.stopPrank();
    }
}
