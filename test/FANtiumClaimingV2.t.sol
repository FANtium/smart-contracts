// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { IFANtiumNFT, CollectionData } from "src/interfaces/IFANtiumNFT.sol";
import { IFANtiumClaiming } from "src/interfaces/IFANtiumClaiming.sol";
import { IFANtiumUserManager } from "src/interfaces/IFANtiumUserManager.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumClaimingFactory } from "test/setup/FANtiumClaimingFactory.sol";
import {
    DistributionEvent, DistributionEventData, DistributionEventErrorReason
} from "src/interfaces/IFANtiumClaiming.sol";

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
    function test_distributionEvents_non_existing_event() public view {
        // Test that a non-existent distribution event returns default/empty values
        DistributionEvent memory event0 = fantiumClaiming.distributionEvents(9999);

        assertEq(event0.exists, false, "Distribution event should not exist for ID 0");
    }

    // createDistributionEvent
    // ========================================================================
    function test_createDistributionEvent_revert_startTimeGreaterThanCloseTime() public {
        // Prepare distribution event data
        DistributionEventData memory data = DistributionEventData({
            collectionIds: new uint256[](1),
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18, // Example tournament earnings
            totalOtherEarnings: 5000 * 10 ** 18, // Example other earnings
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 2 days, // Start in the future
            closeTime: block.timestamp + 1 days // Close < Start
         });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumClaiming.InvalidDistributionEvent.selector, DistributionEventErrorReason.INVALID_TIME
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.createDistributionEvent(data);
    }

    function test_createDistributionEvent_revert_invalid_collection_ids() public {
        // Prepare distribution event data
        DistributionEventData memory data = DistributionEventData({
            collectionIds: new uint256[](0), // empty array
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18, // Example tournament earnings
            totalOtherEarnings: 5000 * 10 ** 18, // Example other earnings
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumClaiming.InvalidDistributionEvent.selector, DistributionEventErrorReason.INVALID_COLLECTION_IDS
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.createDistributionEvent(data);
    }

    // todo: all below tests fail [FAIL: call reverted as expected, but without data]
        function test_createDistributionEvent_revert_invalid_collection_ids_collection_does_not_exist() public {
            CollectionData memory collectionData = CollectionData({
                athleteAddress: payable(makeAddr("athlete")),
                athletePrimarySalesBPS: 5000, // 50%
                athleteSecondarySalesBPS: 1000, // 10%
                fantiumSalesAddress: payable(makeAddr("fantiumSales")),
                fantiumSecondarySalesBPS: 500, // 5%
                launchTimestamp: block.timestamp + 1 days,
                maxInvocations: 100,
                otherEarningShare1e7: 5_000_000, // 50%
                price: 100 ether,
                tournamentEarningShare1e7: 2_500_000 // 25%
            });

            vm.prank(fantiumNFT_manager);
            uint256 collectionId = fantiumNFT.createCollection(collectionData);

            uint256[] memory collectionIdsArray = new uint256[](2);
            collectionIdsArray[0] = collectionId;
            collectionIdsArray[1] = 13; // collection doesn't exist

            // Prepare distribution event data
            DistributionEventData memory distributionEventData = DistributionEventData({
                collectionIds: collectionIdsArray,
                athleteAddress: payable(makeAddr("athleteAddress")),
                totalTournamentEarnings: 10_000 * 10 ** 18, // Example tournament earnings
                totalOtherEarnings: 5000 * 10 ** 18, // Example other earnings
                fantiumFeeBPS: 500, // 5% fee
                fantiumAddress: payable(makeAddr("fantiumAddress")),
                startTime: block.timestamp + 1 days,
                closeTime: block.timestamp + 2 days
            });

            vm.expectRevert(
                abi.encodeWithSelector(
                    IFANtiumClaiming.InvalidDistributionEvent.selector, DistributionEventErrorReason.INVALID_COLLECTION_IDS
                )
            );

            vm.prank(fantiumClaiming_manager);
            fantiumClaiming.createDistributionEvent(distributionEventData);
        }

    function test_createDistributionEvent_revert_invalid_fantium_fee_bps() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 12;
        collectionIdsArray[1] = 13;

        // Prepare distribution event data
        DistributionEventData memory data = DistributionEventData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18, // Example tournament earnings
            totalOtherEarnings: 5000 * 10 ** 18, // Example other earnings
            fantiumFeeBPS: 20_000, // BPS > BPS_BASE
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumClaiming.InvalidDistributionEvent.selector, DistributionEventErrorReason.INVALID_FANTIUM_FEE_BPS
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.createDistributionEvent(data);
    }

    function test_createDistributionEvent_revert_invalid_address() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 12;
        collectionIdsArray[1] = 13;

        // Prepare distribution event data
        DistributionEventData memory data = DistributionEventData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(address(0)), // invalid address
            totalTournamentEarnings: 10_000 * 10 ** 18, // Example tournament earnings
            totalOtherEarnings: 5000 * 10 ** 18, // Example other earnings
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumClaiming.InvalidDistributionEvent.selector, DistributionEventErrorReason.INVALID_ADDRESS
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.createDistributionEvent(data);
    }

    function test_createDistributionEvent_revert_invalid_amount() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 12;
        collectionIdsArray[1] = 13;

        // Prepare distribution event data
        DistributionEventData memory data = DistributionEventData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000_000_000 * 10 ** 18, // Too much money
            totalOtherEarnings: 5000 * 10 ** 18, // Example other earnings
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumClaiming.InvalidDistributionEvent.selector, DistributionEventErrorReason.INVALID_AMOUNT
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.createDistributionEvent(data);
    }
}
