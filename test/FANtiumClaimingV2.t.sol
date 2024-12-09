// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { IFANtiumNFT, CollectionData } from "src/interfaces/IFANtiumNFT.sol";
import { IFANtiumClaiming } from "src/interfaces/IFANtiumClaiming.sol";
import { IFANtiumUserManager } from "src/interfaces/IFANtiumUserManager.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumClaimingFactory } from "test/setup/FANtiumClaimingFactory.sol";
import {
    Distribution,
    DistributionData,
    DistributionErrorReason,
    DistributionFundingErrorReason
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

    // distributions
    // ========================================================================
    function test_distributions_non_existing_event() public view {
        // Test that a non-existent distribution returns default/empty values
        Distribution memory event0 = fantiumClaiming.distributions(9999);
        assertEq(event0.exists, false, "Distribution should not exist for ID 9999");
    }

    // createDistribution
    // ========================================================================
    function test_createDistribution_revert_startTimeGreaterThanCloseTime() public {
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

    function test_createDistribution_revert_invalid_collection_ids() public {
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

    function test_createDistribution_revert_invalid_collection_ids_collection_does_not_exist() public {
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

    function test_createDistribution_revert_invalid_fantium_fee_bps() public {
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

    function test_createDistribution_revert_invalid_address() public {
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

    function test_createDistribution_revert_invalid_amount() public {
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

    function test_createDistribution_ok_creates_distribution_event() public {
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

    function test_updateDistribution_revert_event_closed() public {
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

    function test_updateDistribution_ok_updated() public {
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

    function test_fundDistribution_revert_only_athlete_can_fund() public {
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

    function test_fundDistribution_revert_funding_done() public {
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

    function test_fundDistribution_revert_event_closed() public {
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

    // todo
    //    function test_fundDistribution_ok_success() public {
    //        address athlete = makeAddr("athlete");
    //
    //        // Prepare distribution data
    //        uint256[] memory collectionIdsArray = new uint256[](1);
    //        collectionIdsArray[0] = 1;
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
    //        // Create distribution
    //        vm.prank(fantiumClaiming_manager);
    //        uint256 distEventId = fantiumClaiming.createDistribution(data);
    //
    //        // todo: below is 0, so the test reverts with FUNDING_ALREADY_DONE. How can we update these properties?
    //        uint256 totalAmount = fantiumClaiming.distributions(distEventId).tournamentDistributionAmount
    //            + fantiumClaiming.distributions(distEventId).otherDistributionAmount;
    //        uint256 missingAmount = totalAmount - fantiumClaiming.distributions(distEventId).amountPaidIn;
    //
    //        // Fund the distribution
    //        vm.startPrank(athlete);
    //        fantiumClaiming.fundDistribution(distEventId);
    //        vm.stopPrank();
    //
    //        // Assertions
    //        Distribution memory updatedEvent = fantiumClaiming.distributions(distEventId);
    //        assertEq(updatedEvent.amountPaidIn, totalAmount, "Amount paid in should match total amount");
    //    }
}
