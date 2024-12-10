// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IFANtiumNFT, CollectionData, Collection } from "src/interfaces/IFANtiumNFT.sol";
import { IFANtiumClaiming } from "src/interfaces/IFANtiumClaiming.sol";
import { IFANtiumUserManager } from "src/interfaces/IFANtiumUserManager.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumClaimingFactory } from "test/setup/FANtiumClaimingFactory.sol";
import {
    Distribution,
    DistributionData,
    DistributionErrorReason,
    DistributionFundingErrorReason,
    DistributionCloseErrorReason,
    ClaimErrorReason
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
    function test_setFANtiumNFT_ok_asAdmin() public {
        address newFANtiumNFT = makeAddr("newFANtiumNFT");

        vm.prank(fantiumClaiming_admin);
        fantiumClaiming.setFANtiumNFT(IFANtiumNFT(newFANtiumNFT));

        assertEq(address(fantiumClaiming.fantiumNFT()), newFANtiumNFT);
    }

    function test_setFANtiumNFT_ok_asManager() public {
        address newFANtiumNFT = makeAddr("newFANtiumNFT");

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.setFANtiumNFT(IFANtiumNFT(newFANtiumNFT));

        assertEq(address(fantiumClaiming.fantiumNFT()), newFANtiumNFT);
    }

    function test_setFANtiumNFT_revert_unauthorized() public {
        address newFANtiumNFT = makeAddr("newFANtiumNFT");
        address oldFANtiumNFT = address(fantiumClaiming.fantiumNFT());

        expectMissingRole(nobody, fantiumClaiming.MANAGER_ROLE());
        vm.prank(nobody);
        fantiumClaiming.setFANtiumNFT(IFANtiumNFT(newFANtiumNFT));

        assertEq(address(fantiumClaiming.fantiumNFT()), oldFANtiumNFT);
    }

    // setUserManager
    // ========================================================================
    function test_setUserManager_ok_asAdmin() public {
        address newUserManagerContract = makeAddr("newUserManagerContract");

        vm.prank(fantiumClaiming_admin);
        fantiumClaiming.setUserManager(IFANtiumUserManager(newUserManagerContract));

        assertEq(address(fantiumClaiming.userManager()), newUserManagerContract);
    }

    function test_setUserManager_ok_asManager() public {
        address newUserManagerContract = makeAddr("newUserManagerContract");

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.setUserManager(IFANtiumUserManager(newUserManagerContract));

        assertEq(address(fantiumClaiming.userManager()), newUserManagerContract);
    }

    function test_setUserManager_revert_unauthorized() public {
        address newUserManagerContract = makeAddr("newUserManagerContract");
        address oldUserManagerContract = address(fantiumClaiming.userManager());

        expectMissingRole(nobody, fantiumClaiming.MANAGER_ROLE());
        vm.prank(nobody);
        fantiumClaiming.setUserManager(IFANtiumUserManager(newUserManagerContract));

        assertEq(address(fantiumClaiming.userManager()), oldUserManagerContract);
    }

    // setGlobalPayoutToken
    // ========================================================================
    function test_setGlobalPayoutToken_ok_asAdmin() public {
        address newPayoutToken = makeAddr("newPayoutToken");

        vm.prank(fantiumClaiming_admin);
        fantiumClaiming.setGlobalPayoutToken(newPayoutToken);

        assertEq(address(fantiumClaiming.globalPayoutToken()), newPayoutToken);
    }

    function test_setGlobalPayoutToken_ok_asManager() public {
        address newPayoutToken = makeAddr("newPayoutToken");

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.setGlobalPayoutToken(newPayoutToken);

        assertEq(address(fantiumClaiming.globalPayoutToken()), newPayoutToken);
    }

    function test_setGlobalPayoutToken_revert_unauthorized() public {
        address newPayoutToken = makeAddr("newPayoutToken");
        address oldPayoutToken = address(fantiumClaiming.globalPayoutToken());

        expectMissingRole(nobody, fantiumClaiming.MANAGER_ROLE());
        vm.prank(nobody);
        fantiumClaiming.setGlobalPayoutToken(newPayoutToken);

        assertEq(address(fantiumClaiming.globalPayoutToken()), oldPayoutToken);
    }

    // distributions
    // ========================================================================
    function test_distributions_revert_nonExistingEvent() public view {
        // Test that a non-existent distribution returns default/empty values
        Distribution memory event0 = fantiumClaiming.distributions(9999);
        assertEq(event0.exists, false, "Distribution should not exist for ID 9999");
    }

    // createDistribution
    // ========================================================================
    function test_createDistribution_revert_invalidTime() public {
        // Prepare distribution data
        DistributionData memory data = DistributionData({
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
            abi.encodeWithSelector(IFANtiumClaiming.InvalidDistribution.selector, DistributionErrorReason.INVALID_TIME)
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.createDistribution(data);
    }

    function test_createDistribution_revert_emptyCollectionIds() public {
        // Prepare distribution data
        DistributionData memory data = DistributionData({
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
                IFANtiumClaiming.InvalidDistribution.selector, DistributionErrorReason.INVALID_COLLECTION_IDS
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.createDistribution(data);
    }

    function test_createDistribution_revert_nonExistentCollection() public {
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
        collectionIdsArray[1] = 999_999; // collection doesn't exist

        // Prepare distribution data
        DistributionData memory distributionData = DistributionData({
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
                IFANtiumClaiming.InvalidDistribution.selector, DistributionErrorReason.INVALID_COLLECTION_IDS
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.createDistribution(distributionData);
    }

    function test_createDistribution_revert_invalidFeeBps() public {
        // These collections exist, see test/fixtures/collections.json
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
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
                IFANtiumClaiming.InvalidDistribution.selector, DistributionErrorReason.INVALID_FANTIUM_FEE_BPS
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.createDistribution(data);
    }

    function test_createDistribution_revert_invalidAddress() public {
        // These collections exist, see test/fixtures/collections.json
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
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
                IFANtiumClaiming.InvalidDistribution.selector, DistributionErrorReason.INVALID_ADDRESS
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.createDistribution(data);
    }

    function test_createDistribution_revert_invalidAmount() public {
        // These collections exist, see test/fixtures/collections.json
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
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
                IFANtiumClaiming.InvalidDistribution.selector, DistributionErrorReason.INVALID_AMOUNT
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.createDistribution(data);
    }

    function test_createDistribution_ok_success() public {
        // These collections exist, see test/fixtures/collections.json
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        assertEq(distEventId, 1, "New distribution id");
    }

    function test_updateDistribution_revert_alreadyClosed() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        // Use the contract's method to close the distribution
        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.closeDistribution(distEventId);

        assertTrue(fantiumClaiming.distributions(distEventId).closed, "Distr. event 'closed' property is updated");

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumClaiming.InvalidDistribution.selector, DistributionErrorReason.ALREADY_CLOSED
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.updateDistribution(distEventId, data);
    }

    function test_updateDistribution_ok_success() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        // Prepare update
        DistributionData memory data2 = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress2")),
            totalTournamentEarnings: 15_000 * 10 ** 18,
            totalOtherEarnings: 6000 * 10 ** 18,
            fantiumFeeBPS: 600,
            fantiumAddress: payable(makeAddr("fantiumAddress2")),
            startTime: block.timestamp + 2 days,
            closeTime: block.timestamp + 3 days
        });

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.updateDistribution(distEventId, data2);

        assertEq(
            fantiumClaiming.distributions(distEventId).athleteAddress,
            payable(makeAddr("athleteAddress2")),
            "athlete address is updated"
        );
        assertEq(
            fantiumClaiming.distributions(distEventId).totalTournamentEarnings,
            15_000 * 10 ** 18,
            "totalTournamentEarnings is updated"
        );
        assertEq(
            fantiumClaiming.distributions(distEventId).totalOtherEarnings,
            6000 * 10 ** 18,
            "totalOtherEarnings is updated"
        );
        assertEq(fantiumClaiming.distributions(distEventId).fantiumFeeBPS, 600, "fantiumFeeBPS is updated");
        assertEq(
            fantiumClaiming.distributions(distEventId).fantiumFeeAddress,
            payable(makeAddr("fantiumAddress2")),
            "fantiumAddress is updated"
        );
        assertEq(fantiumClaiming.distributions(distEventId).startTime, block.timestamp + 2 days, "startTime is updated");
        assertEq(fantiumClaiming.distributions(distEventId).closeTime, block.timestamp + 3 days, "closeTime is updated");
    }

    // fundDistribution
    // ========================================================================
    function test_fundDistribution_ok_success() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        address athlete = makeAddr("athlete");

        // Prepare distribution data
        uint256 collectionId = 1;
        uint256[] memory collectionIdsArray = new uint256[](1);
        collectionIdsArray[0] = collectionId;

        // We mint some tokens so the distribution has a value > 0
        mintTo(collectionId, 1, user1);
        mintTo(collectionId, 2, user2);
        mintTo(collectionId, 3, user3);

        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(athlete),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500,
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        // Create distribution
        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        uint256 totalAmount = fantiumClaiming.distributions(distEventId).tournamentDistributionAmount
            + fantiumClaiming.distributions(distEventId).otherDistributionAmount;
        assertGt(totalAmount, 0, "Total amount is greater than 0");

        uint256 missingAmount = totalAmount - fantiumClaiming.distributions(distEventId).amountPaidIn;
        assertGt(missingAmount, 0, "Missing amount is greater than 0");

        // Fund the distribution
        vm.startPrank(athlete);
        deal(address(usdc), athlete, missingAmount);
        usdc.approve(address(fantiumClaiming), missingAmount);
        fantiumClaiming.fundDistribution(distEventId);
        vm.stopPrank();

        // Assertions
        Distribution memory updatedEvent = fantiumClaiming.distributions(distEventId);
        assertEq(updatedEvent.amountPaidIn, totalAmount, "Amount paid in should match total amount");
    }

    function test_fundDistribution_revert_nonAthlete() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        vm.expectRevert();
        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumClaiming.AthleteOnly.selector,
                distEventId,
                payable(makeAddr("someRandomAddress")),
                payable(makeAddr("athleteAddress"))
            )
        );

        vm.prank(payable(makeAddr("someRandomAddress")));
        fantiumClaiming.fundDistribution(distEventId);
    }

    function test_fundDistribution_revert_alreadyFunded() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumClaiming.InvalidDistributionFunding.selector,
                DistributionFundingErrorReason.FUNDING_ALREADY_DONE
            )
        );

        vm.prank(payable(makeAddr("athleteAddress")));
        fantiumClaiming.fundDistribution(distEventId);
    }

    function test_fundDistribution_revert_alreadyClosed() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        // Use the contract's method to close the distribution
        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.closeDistribution(distEventId);

        assertTrue(fantiumClaiming.distributions(distEventId).closed, "Distr. event 'closed' property is updated");

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumClaiming.InvalidDistributionFunding.selector, DistributionFundingErrorReason.CLOSED
            )
        );

        vm.prank(payable(makeAddr("athleteAddress")));
        fantiumClaiming.fundDistribution(distEventId);
    }

    // batchFundDistribution
    // ========================================================================
    function test_batchFundDistribution_ok_success() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        address athlete = makeAddr("athlete");

        // Prepare distribution data
        uint256 collectionId = 1;
        uint256[] memory collectionIdsArray = new uint256[](1);
        collectionIdsArray[0] = collectionId;

        // We mint some tokens so the distribution has a value > 0
        mintTo(collectionId, 1, user1);
        mintTo(collectionId, 2, user2);
        mintTo(collectionId, 3, user3);

        DistributionData memory data1 = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(athlete),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500,
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        DistributionData memory data2 = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(athlete),
            totalTournamentEarnings: 20_000 * 10 ** 18,
            totalOtherEarnings: 10_000 * 10 ** 18,
            fantiumFeeBPS: 500,
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 3 days,
            closeTime: block.timestamp + 4 days
        });

        // Create distribution events
        vm.prank(fantiumClaiming_manager);
        uint256 distEventId1 = fantiumClaiming.createDistribution(data1);
        vm.prank(fantiumClaiming_manager);
        uint256 distEventId2 = fantiumClaiming.createDistribution(data2);

        uint256[] memory distributionEventIdsArray = new uint256[](2);
        distributionEventIdsArray[0] = distEventId1;
        distributionEventIdsArray[1] = distEventId2;

        uint256 totalAmount1 = fantiumClaiming.distributions(distEventId1).tournamentDistributionAmount
            + fantiumClaiming.distributions(distEventId1).otherDistributionAmount;
        assertGt(totalAmount1, 0, "Total amount is greater than 0");

        uint256 totalAmount2 = fantiumClaiming.distributions(distEventId2).tournamentDistributionAmount
            + fantiumClaiming.distributions(distEventId2).otherDistributionAmount;
        assertGt(totalAmount2, 0, "Total amount is greater than 0");

        uint256 totalAmount = totalAmount1 + totalAmount2;

        // batch fund distribution events
        vm.startPrank(athlete);
        deal(address(usdc), athlete, totalAmount);
        usdc.approve(address(fantiumClaiming), totalAmount);
        fantiumClaiming.batchFundDistribution(distributionEventIdsArray);
        vm.stopPrank();

        // Assertions
        Distribution memory updatedEvent1 = fantiumClaiming.distributions(distEventId1);
        Distribution memory updatedEvent2 = fantiumClaiming.distributions(distEventId2);
        assertEq(updatedEvent1.amountPaidIn, totalAmount1, "Amount paid in should match total amount for 1st event");
        assertEq(updatedEvent2.amountPaidIn, totalAmount2, "Amount paid in should match total amount for 2nd event");
    }

    // closeDistribution
    // ========================================================================
    function test_closeDistribution_ok_success() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        // close the distribution
        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.closeDistribution(distEventId);

        assertTrue(fantiumClaiming.distributions(distEventId).closed, "Distr. event 'closed' property is updated");
        // todo: test this line payOutToken.safeTransfer(existingDE.athleteAddress, closingAmount);
    }

    function test_closeDistribution_revert_alreadyClosed() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        // Use the contract's method to close the distribution
        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.closeDistribution(distEventId);
        assertTrue(fantiumClaiming.distributions(distEventId).closed, "Distr. event 'closed' property is updated");

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumClaiming.InvalidDistributionClose.selector,
                DistributionCloseErrorReason.DISTRIBUTION_ALREADY_CLOSED
            )
        );

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.closeDistribution(distEventId);
    }

    // isEligibleForClaim
    // ========================================================================
    function test_isEligibleForClaim_ok_returnsFalseCollectionDoesNotExist() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        uint256 mockTokenId = 5_010_026; // Collection ID: 5, Version: 0, Number: 26

        bool returnValue = fantiumClaiming.isEligibleForClaim(distEventId, mockTokenId);

        assertFalse(returnValue);
    }

    function test_isEligibleForClaim_ok_returnsFalseTokenNumberBiggerThanMintedTokens() public {
        uint256[] memory collectionIdsArray = new uint256[](1);
        collectionIdsArray[0] = 1;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        uint256 mockTokenId = 1_000_026; // Collection ID: 1, Version: 0, Number: 26

        // we minted 0 tokens, so _distributionToCollectionInfo[distributionId][collectionId].mintedTokens returns 0
        bool returnValue = fantiumClaiming.isEligibleForClaim(distEventId, mockTokenId);

        assertFalse(returnValue);
    }

    function test_isEligibleForClaim_ok_returnsTrue() public {
        address user1 = makeAddr("user1");

        // Prepare distribution data
        uint256 collectionId = 1;
        uint256[] memory collectionIdsArray = new uint256[](1);
        collectionIdsArray[0] = collectionId;

        // We mint some tokens
        mintTo(collectionId, 30, user1);

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        uint256 mockTokenId = 1_000_026; // Collection ID: 1, Version: 0, Number: 26

        bool returnValue = fantiumClaiming.isEligibleForClaim(distEventId, mockTokenId);

        assertTrue(returnValue);
    }

    // claim
    // ========================================================================
    function test_claim_revert_distributionAlreadyClosed() public {
        uint256[] memory collectionIdsArray = new uint256[](2);
        collectionIdsArray[0] = 1;
        collectionIdsArray[1] = 2;

        // Prepare distribution data
        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(makeAddr("athleteAddress")),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500, // 5% fee
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        // Use the contract's method to close the distribution
        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.closeDistribution(distEventId);
        assertTrue(fantiumClaiming.distributions(distEventId).closed, "Distr. event 'closed' property is updated");

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumClaiming.InvalidDistributionClose.selector,
                DistributionCloseErrorReason.DISTRIBUTION_ALREADY_CLOSED
            )
        );

        uint256 mockTokenId = 1_000_026; // Collection ID: 1, Version: 0, Number: 26

        vm.prank(payable(makeAddr("userAddress")));
        fantiumClaiming.claim(mockTokenId, distEventId);
    }

    function test_claim_revert_eventNotPaidIn() public {
        address user1 = makeAddr("user1");
        address athlete = makeAddr("athlete");

        // Prepare distribution data
        uint256 collectionId = 1;
        uint256[] memory collectionIdsArray = new uint256[](1);
        collectionIdsArray[0] = collectionId;

        // We mint some tokens
        mintTo(collectionId, 10, user1);

        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(athlete),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500,
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        // Create distribution events
        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);
        uint256 mockTokenId = 1_010_026; // Collection ID: 1, Version: 0, Number: 26

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumClaiming.InvalidClaim.selector, ClaimErrorReason.NOT_FULLY_PAID_IN)
        );

        vm.prank(user1);
        fantiumClaiming.claim(mockTokenId, distEventId);
    }

    function test_claim_revert_notTokenOwner() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address athlete = makeAddr("athlete");

        // Prepare distribution data
        uint256 collectionId = 1;
        uint256[] memory collectionIdsArray = new uint256[](1);
        collectionIdsArray[0] = collectionId;

        // We mint some tokens
        mintTo(collectionId, 10, user1);
        mintTo(collectionId, 10, user2);

        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(athlete),
            totalTournamentEarnings: 10_000 * 10 ** 18,
            totalOtherEarnings: 5000 * 10 ** 18,
            fantiumFeeBPS: 500,
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        // Create distribution events
        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        // Fund the distribution
        uint256 totalAmount = fantiumClaiming.distributions(distEventId).tournamentDistributionAmount
            + fantiumClaiming.distributions(distEventId).otherDistributionAmount;
        assertGt(totalAmount, 0, "Total amount is greater than 0");

        uint256 missingAmount = totalAmount - fantiumClaiming.distributions(distEventId).amountPaidIn;
        assertGt(missingAmount, 0, "Missing amount is greater than 0");

        vm.startPrank(athlete);
        deal(address(usdc), athlete, missingAmount);
        usdc.approve(address(fantiumClaiming), missingAmount);
        fantiumClaiming.fundDistribution(distEventId);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumClaiming.InvalidClaim.selector, ClaimErrorReason.ONLY_TOKEN_OWNER)
        );

        uint256 mockTokenId = 1_000_001; // Collection ID: 1, Version: 0, Number: 1
        vm.prank(payable(user2));
        fantiumClaiming.claim(mockTokenId, distEventId);
    }

    // todo: this test fails [Revert] EvmError: Revert. Error in this line userManager.isIDENT(_msgSender())
    //    function test_claim_revert_notIdented() public {
    //        address user1 = makeAddr("user1");
    //        address athlete = makeAddr("athlete");
    //
    //        // Prepare distribution data
    //        uint256 collectionId = 1;
    //        uint256[] memory collectionIdsArray = new uint256[](1);
    //        collectionIdsArray[0] = collectionId;
    //
    //        // set user as KYCed
    //        vm.prank(userManager_kycManager);
    //        userManager.setKYC(user1, true);
    //        assertTrue(userManager.isKYCed(user1));
    //
    //        // ensure that the launch timestamp has passed
    //        Collection memory collection = fantiumNFT.collections(collectionId);
    //        if (block.timestamp < collection.launchTimestamp) {
    //            skip(collection.launchTimestamp + 1 days);
    //        }
    //
    //        // Mint some tokens
    //        vm.prank(user1);
    //        mintTo(collectionId, 10, user1);
    //
    //        DistributionData memory data = DistributionData({
    //            collectionIds: collectionIdsArray,
    //            athleteAddress: payable(athlete),
    //            totalTournamentEarnings: 10_000 * 10 ** 18,
    //            totalOtherEarnings: 5000 * 10 ** 18,
    //            fantiumFeeBPS: 500,
    //            fantiumAddress: payable(makeAddr("fantiumAddress")),
    //            startTime: block.timestamp + 1 days,
    //            closeTime: block.timestamp + 2 days
    //        });
    //
    //        // Create distribution events
    //        vm.prank(fantiumClaiming_manager);
    //        uint256 distEventId = fantiumClaiming.createDistribution(data);
    //
    //        // Fund the distribution
    //        uint256 totalAmount = fantiumClaiming.distributions(distEventId).tournamentDistributionAmount
    //            + fantiumClaiming.distributions(distEventId).otherDistributionAmount;
    //        assertGt(totalAmount, 0, "Total amount is greater than 0");
    //
    //        uint256 missingAmount = totalAmount - fantiumClaiming.distributions(distEventId).amountPaidIn;
    //        assertGt(missingAmount, 0, "Missing amount is greater than 0");
    //
    //        vm.startPrank(athlete);
    //        deal(address(usdc), athlete, missingAmount);
    //        usdc.approve(address(fantiumClaiming), missingAmount);
    //        fantiumClaiming.fundDistribution(distEventId);
    //        vm.stopPrank();
    //
    //        vm.expectRevert(
    //            abi.encodeWithSelector(IFANtiumClaiming.InvalidClaim.selector, ClaimErrorReason.NOT_IDENTED)
    //        );
    //
    //        uint256 mockTokenId = 1_000_001; // Collection ID: 1, Version: 0, Number: 1
    //        vm.prank(payable(user1));
    //        fantiumClaiming.claim(mockTokenId, distEventId);
    //    }

    function test_computeShares_ok_success() public {
        address user1 = makeAddr("user1");
        address athlete = makeAddr("athlete");

        // Prepare distribution data
        uint256 collectionId = 1;
        uint256[] memory collectionIdsArray = new uint256[](1);
        collectionIdsArray[0] = collectionId;

        uint24 invocationNumber = 10;

        // We mint some tokens
        mintTo(collectionId, invocationNumber, user1);

        uint256 totalTournamentEarnings = 10_000 * 10 ** 18;
        uint256 totalOtherEarnings = 5000 * 10 ** 18;

        DistributionData memory data = DistributionData({
            collectionIds: collectionIdsArray,
            athleteAddress: payable(athlete),
            totalTournamentEarnings: totalTournamentEarnings,
            totalOtherEarnings: totalOtherEarnings,
            fantiumFeeBPS: 500,
            fantiumAddress: payable(makeAddr("fantiumAddress")),
            startTime: block.timestamp + 1 days,
            closeTime: block.timestamp + 2 days
        });

        // Create distribution events
        vm.prank(fantiumClaiming_manager);
        uint256 distEventId = fantiumClaiming.createDistribution(data);

        uint256 tournamentEarningsShare1e7 = 800;
        uint256 otherEarningShare1e7 = 100;

        vm.prank(fantiumClaiming_manager);
        fantiumClaiming.computeShares(distEventId);

        uint256 expectedTournamentDistributionAmount =
            invocationNumber * tournamentEarningsShare1e7 * totalTournamentEarnings / 1e7;
        uint256 expectedOtherDistributionAmount = invocationNumber * otherEarningShare1e7 * totalOtherEarnings / 1e7;

        assertEq(
            fantiumClaiming.distributions(distEventId).tournamentDistributionAmount,
            expectedTournamentDistributionAmount
        );
        assertEq(fantiumClaiming.distributions(distEventId).otherDistributionAmount, expectedOtherDistributionAmount);
    }
}
