// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { IFANtiumNFT } from "src/interfaces/IFANtiumNFT.sol";
import { IFANtiumUserManager } from "src/interfaces/IFANtiumUserManager.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumClaimingFactory } from "test/setup/FANtiumClaimingFactory.sol";
import { DistributionEvent, DistributionEventData } from "src/interfaces/IFANtiumClaiming.sol";

contract FANtiumClaimingV2Test is BaseTest, FANtiumClaimingFactory {
    function setUp() public virtual override {
        FANtiumClaimingFactory.setUp();
    }

    // upgradeTo
    // ========================================================================
    // function test_upgrade_revert_notAdmin() public {
    //     vm.startPrank(nobody);
    //     vm.expectRevert();
    //     // expectMissingRole(nobody, fantiumClaiming.DEFAULT_ADMIN_ROLE());
    //     UnsafeUpgrades.upgradeProxy(fantiumClaiming_proxy, makeAddr("newImplementattion"), "");
    //     vm.stopPrank();
    // }

    // setFANtiumNFT
    // ========================================================================
    function test_setFANtiumNFT_ok_admin() public {
        address newFANtiumNFT = makeAddr("newFANtiumNFT");

        vm.prank(fantiumClaiming_admin);
        fantiumClaiming.setFANtiumNFT(IFANtiumNFT(newFANtiumNFT));

        assertEq(address(fantiumClaiming.fantiumNFT()), newFANtiumNFT);
    }

    function test_setFANtiumNFT_ok_manager() public {
        address newFANtiumNFT = makeAddr("newFANtiumNFT");

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.setFANtiumNFT(IFANtiumNFT(newFANtiumNFT));

        assertEq(address(fantiumClaiming.fantiumNFT()), newFANtiumNFT);
    }

    function test_setFANtiumNFT_revert_nobody() public {
        address newFANtiumNFT = makeAddr("newFANtiumNFT");
        address oldFANtiumNFT = address(fantiumClaiming.fantiumNFT());

        expectMissingRole(nobody, fantiumClaiming.MANAGER_ROLE());
        vm.prank(nobody);
        fantiumClaiming.setFANtiumNFT(IFANtiumNFT(newFANtiumNFT));

        assertEq(address(fantiumClaiming.fantiumNFT()), oldFANtiumNFT);
    }

    // setUserManager
    // ========================================================================
    function test_setUserManager_ok_admin() public {
        address newUserManagerContract = makeAddr("newUserManagerContract");

        vm.prank(fantiumClaiming_admin);
        fantiumClaiming.setUserManager(IFANtiumUserManager(newUserManagerContract));

        assertEq(address(fantiumClaiming.userManager()), newUserManagerContract);
    }

    function test_setUserManager_ok_manager() public {
        address newUserManagerContract = makeAddr("newUserManagerContract");

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.setUserManager(IFANtiumUserManager(newUserManagerContract));

        assertEq(address(fantiumClaiming.userManager()), newUserManagerContract);
    }

    function test_setUserManager_revert_nobody() public {
        address newUserManagerContract = makeAddr("newUserManagerContract");
        address oldUserManagerContract = address(fantiumClaiming.userManager());

        expectMissingRole(nobody, fantiumClaiming.MANAGER_ROLE());
        vm.prank(nobody);
        fantiumClaiming.setUserManager(IFANtiumUserManager(newUserManagerContract));

        assertEq(address(fantiumClaiming.userManager()), oldUserManagerContract);
    }

    // setGlobalPayoutToken
    // ========================================================================
    function test_setGlobalPayoutToken_ok_admin() public {
        address newPayoutToken = makeAddr("newPayoutToken");

        vm.prank(fantiumClaiming_admin);
        fantiumClaiming.setGlobalPayoutToken(newPayoutToken);

        assertEq(address(fantiumClaiming.globalPayoutToken()), newPayoutToken);
    }

    function test_setGlobalPayoutToken_ok_manager() public {
        address newPayoutToken = makeAddr("newPayoutToken");

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.setGlobalPayoutToken(newPayoutToken);

        assertEq(address(fantiumClaiming.globalPayoutToken()), newPayoutToken);
    }

    function test_setGlobalPayoutToken_revert_nobody() public {
        address newPayoutToken = makeAddr("newPayoutToken");
        address oldPayoutToken = address(fantiumClaiming.globalPayoutToken());

        expectMissingRole(nobody, fantiumClaiming.MANAGER_ROLE());
        vm.prank(nobody);
        fantiumClaiming.setGlobalPayoutToken(newPayoutToken);

        assertEq(address(fantiumClaiming.globalPayoutToken()), oldPayoutToken);
    }

    // distributionEvents
    // ========================================================================
    function test_distributionEvents_non_existing_event() public {
        // Test that a non-existent distribution event returns default/empty values
        DistributionEvent memory event0 = fantiumClaiming.distributionEvents(9999);

        assertEq(event0.exists, false, "Distribution event should not exist for ID 0");
    }

    // createDistributionEvent
    // ========================================================================
//    function test_createDistributionEvent_revert_INVALID_TIME() public {
//        // Prepare distribution event data
//        DistributionEventData memory data = DistributionEventData({
//        collectionIds: new uint256[](1),
//        athleteAddress: payable(makeAddr("athleteAddress")),
//        totalTournamentEarnings: 10000 * 10**18,  // Example tournament earnings
//        totalOtherEarnings: 5000 * 10**18,        // Example other earnings
//        fantiumFeeBPS: 500,                       // 5% fee
//        fantiumAddress:  payable(makeAddr("fantiumAddress")),
//        startTime: block.timestamp + 2 days,      // Start in the future
//        closeTime: block.timestamp + 1 days      // Close in the past
//        });
//
//        vm.startPrank(fantiumClaiming_manager);
//
//        vm.expectRevert("INVALID_TIME");
//
//        fantiumClaiming.createDistributionEvent(data);
//    }
}
