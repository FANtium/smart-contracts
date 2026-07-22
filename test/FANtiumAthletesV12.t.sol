// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Vm } from "forge-std/Vm.sol";
import {
    Collection,
    CollectionData,
    CollectionErrorReason,
    IFANtiumAthletes,
    MintErrorReason,
    PhaseSeed,
    PricePhase,
    SaleStatus,
    UpgradeErrorReason
} from "src/interfaces/IFANtiumAthletes.sol";
import { IRescue } from "src/interfaces/IRescue.sol";
import { TokenVersionUtil } from "src/utils/TokenVersionUtil.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumAthletesFactory } from "test/setup/FANtiumAthletesFactory.sol";
import { EIP712Domain } from "test/utils/EIP712Signer.sol";

contract FANtiumAthletesV12Test is BaseTest, FANtiumAthletesFactory {
    using Strings for uint256;

    address public recipient = makeAddr("recipient");

    function setUp() public override {
        FANtiumAthletesFactory.setUp();
    }

    // name
    // ========================================================================
    function test_name() public view {
        assertEq(fantiumAthletes.name(), "FANtium");
    }

    // symbol
    // ========================================================================
    function test_symbol() public view {
        assertEq(fantiumAthletes.symbol(), "FAN");
    }

    // pause
    // ========================================================================
    function test_pause_ok_admin() public {
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.pause();
        assertTrue(fantiumAthletes.paused());
    }

    function test_pause_revert_unauthorized() public {
        address unauthorized = makeAddr("unauthorized");

        expectMissingRole(unauthorized, fantiumAthletes.DEFAULT_ADMIN_ROLE());
        vm.prank(unauthorized);
        fantiumAthletes.pause();
    }

    // unpause
    // ========================================================================
    function test_unpause_ok_admin() public {
        // First pause the contract
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.pause();
        assertTrue(fantiumAthletes.paused());

        // Then unpause it
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.unpause();
        assertFalse(fantiumAthletes.paused());
    }

    function test_unpause_revert_unauthorized() public {
        // First pause the contract
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.pause();
        assertTrue(fantiumAthletes.paused());

        address unauthorized = makeAddr("unauthorized");

        expectMissingRole(unauthorized, fantiumAthletes.DEFAULT_ADMIN_ROLE());
        vm.prank(unauthorized);
        fantiumAthletes.unpause();
    }

    // supportsInterface
    // ========================================================================
    function test_supportsInterface_ok() public view {
        // ERC165 interface ID
        bytes4 erc165InterfaceId = 0x01ffc9a7;
        assertTrue(fantiumAthletes.supportsInterface(erc165InterfaceId), "Should support ERC165");

        // ERC721 interface ID
        bytes4 erc721InterfaceId = 0x80ac58cd;
        assertTrue(fantiumAthletes.supportsInterface(erc721InterfaceId), "Should support ERC721");

        // ERC721Metadata interface ID
        bytes4 erc721MetadataInterfaceId = 0x5b5e139f;
        assertTrue(fantiumAthletes.supportsInterface(erc721MetadataInterfaceId), "Should support ERC721Metadata");

        // AccessControl interface ID
        bytes4 accessControlInterfaceId = 0x7965db0b;
        assertTrue(fantiumAthletes.supportsInterface(accessControlInterfaceId), "Should support AccessControl");

        // Random interface ID (should return false)
        bytes4 randomInterfaceId = 0x12345678;
        assertFalse(fantiumAthletes.supportsInterface(randomInterfaceId), "Should not support random interface");
    }

    // setBaseURI
    // ========================================================================
    function test_setBaseURI_ok_manager() public {
        string memory newBaseURI = "https://new.com/";
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setBaseURI(newBaseURI);
        assertEq(fantiumAthletes.baseURI(), newBaseURI, "Base URI should be set");
    }

    function test_setBaseURI_ok_admin() public {
        string memory newBaseURI = "https://new.com/";
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setBaseURI(newBaseURI);
        assertEq(fantiumAthletes.baseURI(), newBaseURI, "Base URI should be set");
    }

    function test_setBaseURI_unauthorized() public {
        string memory newBaseURI = "https://new.com/";
        address unauthorized = makeAddr("unauthorized");

        string memory baseURIBefore = fantiumAthletes.baseURI();

        expectMissingRole(unauthorized, fantiumAthletes.DEFAULT_ADMIN_ROLE());
        vm.prank(unauthorized);
        fantiumAthletes.setBaseURI(newBaseURI);
        assertEq(fantiumAthletes.baseURI(), baseURIBefore, "Base URI should not change");
    }

    // isApprovedForAll
    // ========================================================================
    function test_isApprovedForAll_ok_operator() public {
        address owner = makeAddr("owner");
        address operator = makeAddr("operator");

        // Grant operator role to the operator
        vm.startPrank(fantiumAthletes_admin);
        fantiumAthletes.grantRole(fantiumAthletes.OPERATOR_ROLE(), operator);
        vm.stopPrank();

        // Operator should be approved for all tokens
        assertTrue(fantiumAthletes.isApprovedForAll(owner, operator));
    }

    function test_isApprovedForAll_ok_standardApproval() public {
        address owner = makeAddr("owner");
        address operator = makeAddr("operator");

        // Set approval for all
        vm.prank(owner);
        fantiumAthletes.setApprovalForAll(operator, true);

        // Operator should be approved for all tokens
        assertTrue(fantiumAthletes.isApprovedForAll(owner, operator));
    }

    function test_isApprovedForAll_ok_noApproval() public {
        address owner = makeAddr("owner");
        address operator = makeAddr("operator");

        // No approval set
        assertFalse(fantiumAthletes.isApprovedForAll(owner, operator));
    }

    // createCollection
    // ========================================================================
    function test_createCollection_ok() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000, // 50%
            athleteSecondarySalesBPS: 1000, // 10%
            fantiumSecondarySalesBPS: 500, // 5%
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000, // 50%
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000 // 25%
        });

        vm.prank(fantiumAthletes_admin);
        uint256 collectionId = fantiumAthletes.createCollection(data);

        Collection memory collection = fantiumAthletes.collections(collectionId);
        assertEq(collection.athleteAddress, data.athleteAddress);
        assertEq(collection.athletePrimarySalesBPS, data.athletePrimarySalesBPS);
        assertEq(collection.athleteSecondarySalesBPS, data.athleteSecondarySalesBPS);
        assertTrue(collection.exists);
        assertEq(collection.fantiumSecondarySalesBPS, data.fantiumSecondarySalesBPS);
        assertEq(collection.invocations, 0);
        assertEq(uint256(collection.status), uint256(SaleStatus.Pending));
        assertEq(collection.launchTimestamp, data.launchTimestamp);
        assertEq(collection.otherEarningShare1e7, data.otherEarningShare1e7);
        assertEq(collection.tournamentEarningShare1e7, data.tournamentEarningShare1e7);
        assertEq(collection.phases.length, data.phases.length);
        assertEq(collection.phases[0].price, data.phases[0].price);
        assertEq(collection.phases[0].maxInvocations, data.phases[0].maxInvocations);
    }

    function test_createCollection_revert_invalidAthleteAddress() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(address(0)),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_ATHLETE_ADDRESS
            )
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.createCollection(data);
    }

    function test_createCollection_revert_invalidPrimarySalesBPS() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 10_001, // > 100%
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_PRIMARY_SALES_BPS
            )
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.createCollection(data);
    }

    function test_createCollection_revert_invalidSecondarySalesBPSSum() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 9000,
            fantiumSecondarySalesBPS: 2000, // Sum > 100%
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_BPS_SUM)
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.createCollection(data);
    }

    function test_createCollection_revert_invalidMaxInvocations() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 10_000), // sum >= 10_000
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_MAX_INVOCATIONS
            )
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.createCollection(data);
    }

    function test_createCollection_revert_invalidOtherEarningShare() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 10_000_001, // > 100%
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_OTHER_EARNING_SHARE
            )
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.createCollection(data);
    }

    function test_createCollection_revert_invalidTournamentEarningShare() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 10_000_001 // > 100%
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_TOURNAMENT_EARNING_SHARE
            )
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.createCollection(data);
    }

    function test_createCollection_revert_unauthorized() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        address unauthorized = makeAddr("unauthorized");
        expectMissingRole(unauthorized, fantiumAthletes.DEFAULT_ADMIN_ROLE());
        vm.prank(unauthorized);
        fantiumAthletes.createCollection(data);
    }

    // updateCollection
    // ========================================================================
    function test_updateCollection_ok() public {
        uint256 collectionId = 1; // Using existing collection from setup
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("newAthlete")),
            athletePrimarySalesBPS: 6000, // 60%
            athleteSecondarySalesBPS: 1500, // 15%
            fantiumSecondarySalesBPS: 750, // 7.5%
            launchTimestamp: block.timestamp + 2 days,
            otherEarningShare1e7: 6_000_000, // 60%
            phases: singlePhase(200 ether, 200), // Increased from original
            tournamentEarningShare1e7: 3_000_000 // 30%
        });

        Collection memory beforeCollection = fantiumAthletes.collections(collectionId);

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.updateCollection(collectionId, data);

        Collection memory afterCollection = fantiumAthletes.collections(collectionId);

        // Verify all updateable fields changed
        assertEq(afterCollection.athleteAddress, data.athleteAddress);
        assertEq(afterCollection.athletePrimarySalesBPS, data.athletePrimarySalesBPS);
        assertEq(afterCollection.athleteSecondarySalesBPS, data.athleteSecondarySalesBPS);
        assertEq(afterCollection.fantiumSecondarySalesBPS, data.fantiumSecondarySalesBPS);
        assertEq(afterCollection.launchTimestamp, data.launchTimestamp);
        assertEq(afterCollection.otherEarningShare1e7, data.otherEarningShare1e7);
        assertEq(afterCollection.tournamentEarningShare1e7, data.tournamentEarningShare1e7);
        assertEq(afterCollection.phases.length, data.phases.length);
        assertEq(afterCollection.phases[0].price, data.phases[0].price);
        assertEq(afterCollection.phases[0].maxInvocations, data.phases[0].maxInvocations);

        // Verify non-updateable fields remained unchanged
        assertEq(afterCollection.exists, beforeCollection.exists);
        assertEq(afterCollection.invocations, beforeCollection.invocations);
        assertEq(uint256(afterCollection.status), uint256(beforeCollection.status));
    }

    function test_updateCollection_revert_invalidCollectionId() public {
        uint256 invalidCollectionId = 999_999;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.InvalidCollectionId.selector, invalidCollectionId));
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.updateCollection(invalidCollectionId, data);
    }

    function test_updateCollection_revert_phasesDoNotAccommodateInvocations() public {
        uint256 collectionId = 1;
        mintTo(collectionId, 10, recipient); // mint 10 tokens to increase invocations

        Collection memory currentCollection = fantiumAthletes.collections(collectionId);

        // Shrink total supply below current invocations: new phases sum to 5 while 10 are minted.
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, uint256(currentCollection.invocations) - 1),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.PhasesMustAccommodateInvocations.selector, currentCollection.invocations
            )
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_invalidAthleteAddress() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(address(0)),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_ATHLETE_ADDRESS
            )
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_invalidPrimarySalesBPS() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 10_001, // > 100%
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_PRIMARY_SALES_BPS
            )
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_invalidSecondarySalesBPSSum() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 9000,
            fantiumSecondarySalesBPS: 2000, // Sum > 100%
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_BPS_SUM)
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_invalidOtherEarningShare() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 10_000_001, // > 100%
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_OTHER_EARNING_SHARE
            )
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_invalidTournamentEarningShare() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 10_000_001 // > 100%
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_TOURNAMENT_EARNING_SHARE
            )
        );
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_unauthorized() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        address unauthorized = makeAddr("unauthorized");
        expectMissingRole(unauthorized, fantiumAthletes.DEFAULT_ADMIN_ROLE());
        vm.prank(unauthorized);
        fantiumAthletes.updateCollection(collectionId, data);
    }

    // setSaleStatus
    // ========================================================================
    function test_setSaleStatus_ok_admin() public {
        uint256 collectionId = 1;

        vm.expectEmit(true, false, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.SaleStatusUpdated(collectionId, SaleStatus.Paused);
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Paused);

        assertEq(uint256(fantiumAthletes.collections(collectionId).status), uint256(SaleStatus.Paused));
    }

    function test_setSaleStatus_ok_batch() public {
        uint256[] memory collectionIds = new uint256[](3);
        collectionIds[0] = 1;
        collectionIds[1] = 2;
        collectionIds[2] = 3;

        for (uint256 i = 0; i < collectionIds.length; i++) {
            vm.expectEmit(true, false, false, true, address(fantiumAthletes));
            emit IFANtiumAthletes.SaleStatusUpdated(collectionIds[i], SaleStatus.Paused);
        }
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setSaleStatus(collectionIds, SaleStatus.Paused);

        for (uint256 i = 0; i < collectionIds.length; i++) {
            assertEq(uint256(fantiumAthletes.collections(collectionIds[i]).status), uint256(SaleStatus.Paused));
        }
    }

    function test_setSaleStatus_revert_batchWithForeignCollection() public {
        // Collection 1 and 2 share the same athlete in the fixtures; create one owned by another.
        address otherAthlete = makeAddr("otherAthlete");
        CollectionData memory data = CollectionData({
            athleteAddress: payable(otherAthlete),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });
        vm.prank(fantiumAthletes_admin);
        uint256 foreignCollectionId = fantiumAthletes.createCollection(data);

        address athlete = fantiumAthletes.collections(1).athleteAddress;
        uint256[] memory collectionIds = new uint256[](2);
        collectionIds[0] = 1;
        collectionIds[1] = foreignCollectionId;

        // The whole batch reverts: no partial application.
        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.AthleteOnly.selector, foreignCollectionId, athlete, otherAthlete)
        );
        vm.prank(athlete);
        fantiumAthletes.setSaleStatus(collectionIds, SaleStatus.Paused);

        assertEq(uint256(fantiumAthletes.collections(1).status), uint256(SaleStatus.Open));
    }

    function test_setSaleStatus_ok_athlete() public {
        uint256 collectionId = 1;
        address athlete = fantiumAthletes.collections(collectionId).athleteAddress;

        vm.prank(athlete);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Paused);
        assertEq(uint256(fantiumAthletes.collections(collectionId).status), uint256(SaleStatus.Paused));

        vm.prank(athlete);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Open);
        assertEq(uint256(fantiumAthletes.collections(collectionId).status), uint256(SaleStatus.Open));
    }

    function test_setSaleStatus_ok_athleteCanClose() public {
        uint256 collectionId = 1;
        address athlete = fantiumAthletes.collections(collectionId).athleteAddress;

        vm.prank(athlete);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Closed);
        assertEq(uint256(fantiumAthletes.collections(collectionId).status), uint256(SaleStatus.Closed));
    }

    function test_setSaleStatus_ok_adminCanReopenClosed() public {
        uint256 collectionId = 1;

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Closed);

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Open);
        assertEq(uint256(fantiumAthletes.collections(collectionId).status), uint256(SaleStatus.Open));
    }

    function test_setSaleStatus_revert_athleteCannotReopenClosed() public {
        uint256 collectionId = 1;
        address athlete = fantiumAthletes.collections(collectionId).athleteAddress;

        vm.prank(athlete);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Closed);

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.SaleClosed.selector, collectionId));
        vm.prank(athlete);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Open);
    }

    function test_setSaleStatus_revert_invalidCollectionId() public {
        uint256 invalidCollectionId = 999_999;

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.InvalidCollectionId.selector, invalidCollectionId));
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setSaleStatus(singleCollection(invalidCollectionId), SaleStatus.Open);
    }

    function test_setSaleStatus_revert_unauthorized() public {
        uint256 collectionId = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.AthleteOnly.selector,
                collectionId,
                nobody,
                fantiumAthletes.collections(collectionId).athleteAddress
            )
        );
        vm.prank(nobody);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Open);
    }

    function test_setSaleStatus_revert_wrongAthlete() public {
        // Create two collections with different athletes
        address athlete1 = makeAddr("athlete1");
        address athlete2 = makeAddr("athlete2");

        CollectionData memory data1 = CollectionData({
            athleteAddress: payable(athlete1),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        CollectionData memory data2 = CollectionData({
            athleteAddress: payable(athlete2),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: singlePhase(100 ether, 100),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.prank(fantiumAthletes_admin);
        uint256 collectionId1 = fantiumAthletes.createCollection(data1);

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.createCollection(data2);

        // Try to set status of collection1 as athlete2
        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.AthleteOnly.selector, collectionId1, athlete2, athlete1)
        );
        vm.prank(athlete2);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId1), SaleStatus.Open);
    }

    // mintTo — sale state checks
    // ========================================================================
    function test_mintTo_revert_invalidCollectionId() public {
        uint256 collectionId = 999_999; // collection 999_999 does not exist
        uint256 deadline = block.timestamp + 1 hours;

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.InvalidCollectionId.selector, collectionId));
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, 1, recipient, deadline, "");
    }

    function test_mintTo_revert_notMintable() public {
        uint256 collectionId = 1; // collection 1 is mintable

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Pending);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = signMint(recipient, fantiumAthletes.nonces(recipient), collectionId, 1, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.COLLECTION_NOT_MINTABLE)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, 1, recipient, deadline, signature);
    }

    function test_mintTo_revert_notLaunched() public {
        uint256 collectionId = 1; // collection 1 is mintable

        Collection memory collection = fantiumAthletes.collections(collectionId);
        if (block.timestamp > collection.launchTimestamp) {
            rewind(collection.launchTimestamp - 1 days);
        }

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = signMint(recipient, fantiumAthletes.nonces(recipient), collectionId, 1, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.COLLECTION_NOT_LAUNCHED)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, 1, recipient, deadline, signature);
    }

    function test_mintTo_revert_paused() public {
        uint256 collectionId = 5; // collection 5 is paused
        assertEq(uint256(fantiumAthletes.collections(collectionId).status), uint256(SaleStatus.Paused));

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = signMint(recipient, fantiumAthletes.nonces(recipient), collectionId, 1, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.COLLECTION_PAUSED)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, 1, recipient, deadline, signature);
    }

    // getPrimaryRevenueSplits
    // ========================================================================
    function test_getPrimaryRevenueSplits_ok() public view {
        uint256 price = 1000 * 10 ** usdc.decimals();
        uint256 collectionId = 1; // Using collection 1 from fixtures

        (
            uint256 fantiumRevenue,
            address payable fantiumAddress,
            uint256 athleteRevenue,
            address payable athleteAddress
        ) = fantiumAthletes.getPrimaryRevenueSplits(collectionId, price);

        // Get collection to verify calculations
        Collection memory collection = fantiumAthletes.collections(collectionId);

        // Verify revenue splits
        assertEq(athleteRevenue, (price * collection.athletePrimarySalesBPS) / 10_000, "Incorrect athlete revenue");
        assertEq(fantiumRevenue, price - athleteRevenue, "Incorrect fantium revenue");

        // Verify addresses
        assertEq(fantiumAddress, fantiumAthletes.treasury(), "Incorrect treasury address");
        assertEq(athleteAddress, collection.athleteAddress, "Incorrect athlete address");
    }

    // quoteMint
    // ========================================================================
    function test_quoteMint_ok() public view {
        uint256 collectionId = 1; // collection 1 is mintable
        Collection memory collection = fantiumAthletes.collections(collectionId);
        (uint256 price, uint256 activePhaseBefore, uint256 activePhaseAfter, bool soldOutAfter) =
            fantiumAthletes.quoteMint(collectionId, 3);
        assertEq(price, uint256(collection.phases[0].price) * 3 * 10 ** usdc.decimals());
        assertEq(activePhaseBefore, 0);
        assertEq(activePhaseAfter, 0);
        assertFalse(soldOutAfter);
    }

    function test_quoteMint_revert_insufficientSupply() public {
        uint256 collectionId = 6; // collection 6 has 5 max invocations
        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.MAX_INVOCATIONS_REACHED)
        );
        fantiumAthletes.quoteMint(collectionId, 6);
    }

    // mintTo
    // ========================================================================
    function test_mintTo_ok_single() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        (uint256 amountUSDC, uint256 deadline, bytes memory signature) =
            prepareSignedSale(collectionId, quantity, recipient);

        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.Sale(collectionId, quantity, recipient, amountUSDC, 0);
        vm.prank(recipient);
        uint256 lastTokenId = fantiumAthletes.mintTo(collectionId, quantity, recipient, deadline, signature);

        assertEq(fantiumAthletes.ownerOf(lastTokenId), recipient);
    }

    function test_mintTo_ok_batch() public {
        uint24 quantity = 10;
        uint256 collectionId = 1; // collection 1 is mintable

        (
            uint256 amountUSDC,
            uint256 fantiumRevenue,
            address payable fantiumAddress,
            uint256 athleteRevenue,
            address payable athleteAddress
        ) = prepareSale(collectionId, quantity, recipient);
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature =
            signMint(recipient, fantiumAthletes.nonces(recipient), collectionId, quantity, deadline);
        uint256 recipientBalanceBefore = usdc.balanceOf(recipient);

        // Transfers expected
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, fantiumAddress, fantiumRevenue);
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, athleteAddress, athleteRevenue);

        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.Sale(collectionId, quantity, recipient, amountUSDC, 0);
        vm.prank(recipient);
        uint256 lastTokenId = fantiumAthletes.mintTo(collectionId, quantity, recipient, deadline, signature);

        uint256 firstTokenId = lastTokenId - quantity + 1;

        for (uint256 tokenId = firstTokenId; tokenId <= lastTokenId; tokenId++) {
            assertEq(fantiumAthletes.ownerOf(tokenId), recipient);
        }

        assertEq(usdc.balanceOf(recipient), recipientBalanceBefore - amountUSDC);
    }

    function test_mintTo_revert_maxInvocationsReached() public {
        uint256 collectionId = 6; // collection 6 is mintable
        uint24 quantity = 6; // collection 6 has 5 max invocations

        Collection memory collection = fantiumAthletes.collections(collectionId);
        if (block.timestamp < collection.launchTimestamp) {
            vm.warp(collection.launchTimestamp + 1);
        }

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature =
            signMint(recipient, fantiumAthletes.nonces(recipient), collectionId, quantity, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.MAX_INVOCATIONS_REACHED)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, quantity, recipient, deadline, signature);
    }

    function test_mintTo_revert_zeroQuantity() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = signMint(recipient, fantiumAthletes.nonces(recipient), collectionId, 0, deadline);

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.INVALID_QUANTITY));
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, 0, recipient, deadline, signature);
    }

    function test_mintTo_revert_malformedSignature() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory malformedSignature = abi.encodePacked("malformed signature");

        vm.expectRevert("ECDSA: invalid signature length");
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, quantity, recipient, deadline, malformedSignature);
    }

    function test_mintTo_revert_invalidSigner() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = fantiumAthletes.nonces(recipient);

        bytes32 structHash =
            keccak256(abi.encode(fantiumAthletes.MINT_TYPEHASH(), collectionId, quantity, recipient, nonce, deadline));
        bytes memory forgedSignature = typedSignPacked(42_424_242_242_424_242, fantiumAthletesDomain(), structHash);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.INVALID_SIGNATURE)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, quantity, recipient, deadline, forgedSignature);
    }

    function test_mintTo_revert_invalidNonce() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        (, uint256 deadline, bytes memory signature) = prepareSignedSale(collectionId, quantity, recipient);

        // First mint pass, and nonce is incremented
        vm.prank(recipient);
        uint256 lastTokenId = fantiumAthletes.mintTo(collectionId, quantity, recipient, deadline, signature);
        assertEq(fantiumAthletes.ownerOf(lastTokenId), recipient);

        // Second mint fails, because nonce is incremented
        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.INVALID_SIGNATURE)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, quantity, recipient, deadline, signature);
    }

    function test_mintTo_revert_expiredDeadline() public {
        uint256 collectionId = 1;
        uint24 quantity = 1;
        (, uint256 deadline, bytes memory signature) = prepareSignedSale(collectionId, quantity, recipient);

        // Advance past the deadline.
        vm.warp(deadline + 1);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.SIGNATURE_EXPIRED)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, quantity, recipient, deadline, signature);
    }

    function test_mintTo_revert_wrongChainId() public {
        uint256 collectionId = 1;
        uint24 quantity = 1;
        uint256 nonce = fantiumAthletes.nonces(recipient);
        uint256 deadline = block.timestamp + 1 hours;

        EIP712Domain memory wrongDomain = EIP712Domain({
            name: "FANtium Athletes",
            version: "1",
            chainId: block.chainid + 1,
            verifyingContract: address(fantiumAthletes)
        });
        bytes32 structHash =
            keccak256(abi.encode(fantiumAthletes.MINT_TYPEHASH(), collectionId, quantity, recipient, nonce, deadline));
        bytes memory signature = typedSignPacked(fantiumAthletes_signerKey, wrongDomain, structHash);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.INVALID_SIGNATURE)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, quantity, recipient, deadline, signature);
    }

    function test_mintTo_revert_wrongVerifyingContract() public {
        uint256 collectionId = 1;
        uint24 quantity = 1;
        uint256 nonce = fantiumAthletes.nonces(recipient);
        uint256 deadline = block.timestamp + 1 hours;

        EIP712Domain memory wrongDomain = EIP712Domain({
            name: "FANtium Athletes", version: "1", chainId: block.chainid, verifyingContract: address(0x1234)
        });
        bytes32 structHash =
            keccak256(abi.encode(fantiumAthletes.MINT_TYPEHASH(), collectionId, quantity, recipient, nonce, deadline));
        bytes memory signature = typedSignPacked(fantiumAthletes_signerKey, wrongDomain, structHash);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.INVALID_SIGNATURE)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, quantity, recipient, deadline, signature);
    }

    // batchTransferFrom
    // ========================================================================
    function test_batchTransferFrom_ok() public {
        // Mint multiple tokens to the recipient
        uint256 collectionId = 1;
        uint24 quantity = 5;
        uint256 lastTokenId = mintTo(collectionId, quantity, recipient);
        uint256 firstTokenId = lastTokenId - quantity + 1;

        address newOwner = makeAddr("newOwner");
        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            tokenIds[i] = firstTokenId + i;
        }

        // Approve operator
        vm.prank(recipient);
        fantiumAthletes.setApprovalForAll(address(this), true);

        fantiumAthletes.batchTransferFrom(recipient, newOwner, tokenIds);

        // Verify ownership transfer
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(fantiumAthletes.ownerOf(tokenIds[i]), newOwner);
        }
    }

    function test_batchTransferFrom_revert_unauthorized() public {
        // Mint multiple tokens to the recipient
        uint256 collectionId = 1;
        uint24 quantity = 5;
        uint256 lastTokenId = mintTo(collectionId, quantity, recipient);
        uint256 firstTokenId = lastTokenId - quantity + 1;

        address newOwner = makeAddr("newOwner");
        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            tokenIds[i] = firstTokenId + i;
        }

        // Don't approve operator
        vm.expectRevert("ERC721: caller is not token owner or approved");
        fantiumAthletes.batchTransferFrom(recipient, newOwner, tokenIds);
    }

    function test_batchTransferFrom_revert_whenPaused() public {
        // Mint multiple tokens to the recipient
        uint256 collectionId = 1;
        uint24 quantity = 5;
        uint256 lastTokenId = mintTo(collectionId, quantity, recipient);
        uint256 firstTokenId = lastTokenId - quantity + 1;

        address newOwner = makeAddr("newOwner");
        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            tokenIds[i] = firstTokenId + i;
        }

        // Approve operator
        vm.prank(recipient);
        fantiumAthletes.setApprovalForAll(address(this), true);

        // Pause the contract
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.pause();

        vm.expectRevert("Pausable: paused");
        fantiumAthletes.batchTransferFrom(recipient, newOwner, tokenIds);
    }

    // batchSafeTransferFrom
    // ========================================================================
    function test_batchSafeTransferFrom_ok_to_eoa() public {
        // Mint multiple tokens to the recipient
        uint256 collectionId = 1;
        uint24 quantity = 5;
        uint256 lastTokenId = mintTo(collectionId, quantity, recipient);
        uint256 firstTokenId = lastTokenId - quantity + 1;

        address newOwner = makeAddr("newOwner");
        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            tokenIds[i] = firstTokenId + i;
        }

        // Approve operator
        vm.prank(recipient);
        fantiumAthletes.setApprovalForAll(address(this), true);

        fantiumAthletes.batchSafeTransferFrom(recipient, newOwner, tokenIds);

        // Verify ownership transfer
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(fantiumAthletes.ownerOf(tokenIds[i]), newOwner);
        }
    }

    function test_batchSafeTransferFrom_revert_unauthorized() public {
        // Mint multiple tokens to the recipient
        uint256 collectionId = 1;
        uint24 quantity = 5;
        uint256 lastTokenId = mintTo(collectionId, quantity, recipient);
        uint256 firstTokenId = lastTokenId - quantity + 1;

        address newOwner = makeAddr("newOwner");
        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            tokenIds[i] = firstTokenId + i;
        }

        // Don't approve operator
        vm.expectRevert("ERC721: caller is not token owner or approved");
        fantiumAthletes.batchSafeTransferFrom(recipient, newOwner, tokenIds);
    }

    function test_batchSafeTransferFrom_revert_whenPaused() public {
        // Mint multiple tokens to the recipient
        uint256 collectionId = 1;
        uint24 quantity = 5;
        uint256 lastTokenId = mintTo(collectionId, quantity, recipient);
        uint256 firstTokenId = lastTokenId - quantity + 1;

        address newOwner = makeAddr("newOwner");
        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            tokenIds[i] = firstTokenId + i;
        }

        // Approve operator
        vm.prank(recipient);
        fantiumAthletes.setApprovalForAll(address(this), true);

        // Pause the contract
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.pause();

        vm.expectRevert("Pausable: paused");
        fantiumAthletes.batchSafeTransferFrom(recipient, newOwner, tokenIds);
    }

    // tokenURI
    // ========================================================================
    function test_tokenURI_ok() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);
        assertEq(
            fantiumAthletes.tokenURI(tokenId),
            string.concat("https://app.fantium.com/api/metadata/", tokenId.toString())
        );
    }

    // upgradeTokenVersion
    // ========================================================================
    function test_upgradeTokenVersion_ok() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);

        // Verify initial ownership
        assertEq(fantiumAthletes.ownerOf(tokenId), recipient);

        (, uint256 version, uint256 number,) = TokenVersionUtil.getTokenInfo(tokenId);
        // Calculate expected new token ID (version incremented by 1)
        uint256 expectedNewTokenId = TokenVersionUtil.createTokenId(collectionId, version + 1, number);

        vm.prank(fantiumAthletes_tokenUpgrader);
        fantiumAthletes.upgradeTokenVersion(tokenId);

        // Verify old token was burned
        vm.expectRevert("ERC721: invalid token ID");
        fantiumAthletes.ownerOf(tokenId);

        // Verify new token ownership
        assertEq(fantiumAthletes.ownerOf(expectedNewTokenId), recipient);
    }

    function test_upgradeTokenVersion_revert_unauthorized() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);

        address unauthorized = makeAddr("unauthorized");
        expectMissingRole(unauthorized, fantiumAthletes.TOKEN_UPGRADER_ROLE());

        vm.prank(unauthorized);
        fantiumAthletes.upgradeTokenVersion(tokenId);
    }

    function test_upgradeTokenVersion_revert_invalidTokenId() public {
        uint256 invalidTokenId = mintTo(1, 1, recipient) + 1;

        vm.expectRevert("ERC721: invalid token ID");
        vm.prank(fantiumAthletes_tokenUpgrader);
        fantiumAthletes.upgradeTokenVersion(invalidTokenId);
    }

    function test_upgradeTokenVersion_revert_invalidCollectionId() public {
        // Create a token ID with an invalid collection ID
        uint256 invalidCollectionId = 999_999;
        uint256 tokenId = TokenVersionUtil.createTokenId(invalidCollectionId, 0, 1);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidUpgrade.selector, UpgradeErrorReason.INVALID_COLLECTION_ID)
        );
        vm.prank(fantiumAthletes_tokenUpgrader);
        fantiumAthletes.upgradeTokenVersion(tokenId);
    }

    function test_upgradeTokenVersion_revert_versionTooHigh() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);

        vm.startPrank(fantiumAthletes_tokenUpgrader);
        // Upgrade token {TokenVersionUtil.MAX_VERSION} times
        for (uint256 i = 0; i < TokenVersionUtil.MAX_VERSION; i++) {
            tokenId = fantiumAthletes.upgradeTokenVersion(tokenId);
        }

        // ... it's not possible to upgrade the token anymore
        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidUpgrade.selector, UpgradeErrorReason.VERSION_ID_TOO_HIGH)
        );
        fantiumAthletes.upgradeTokenVersion(tokenId);
        vm.stopPrank();
    }

    function test_upgradeTokenVersion_revert_whenPaused() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.pause();

        vm.expectRevert("Pausable: paused");
        vm.prank(fantiumAthletes_tokenUpgrader);
        fantiumAthletes.upgradeTokenVersion(tokenId);
    }

    // rescue
    // ========================================================================
    function test_rescue_ok() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);
        string memory reason = "Emergency rescue needed";

        // Verify initial ownership
        assertEq(fantiumAthletes.ownerOf(tokenId), recipient);

        vm.prank(fantiumAthletes_admin);
        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        emit IRescue.Rescued(tokenId, fantiumAthletes_admin, reason);
        fantiumAthletes.rescue(tokenId, reason);

        // Verify ownership transfer
        assertEq(fantiumAthletes.ownerOf(tokenId), fantiumAthletes_admin);
    }

    function test_rescue_revert_unauthorized() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);
        string memory reason = "Emergency rescue needed";

        address unauthorized = makeAddr("unauthorized");

        expectMissingRole(unauthorized, fantiumAthletes.DEFAULT_ADMIN_ROLE());
        vm.prank(unauthorized);
        fantiumAthletes.rescue(tokenId, reason);
    }

    function test_rescue_revert_invalidTokenId() public {
        uint256 invalidTokenId = 999_999;
        string memory reason = "Emergency rescue needed";

        vm.expectRevert("ERC721: invalid token ID");
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.rescue(invalidTokenId, reason);
    }

    // rescueBatch
    // ========================================================================
    function test_rescueBatch_ok() public {
        uint256 collectionId = 1;
        uint24 quantity = 5;
        uint256 lastTokenId = mintTo(collectionId, quantity, recipient);
        uint256 firstTokenId = lastTokenId - quantity + 1;
        string memory reason = "Emergency batch rescue needed";

        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            tokenIds[i] = firstTokenId + i;
            // Verify initial ownership
            assertEq(fantiumAthletes.ownerOf(tokenIds[i]), recipient);
        }

        vm.prank(fantiumAthletes_admin);
        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        for (uint256 i = 0; i < tokenIds.length; i++) {
            emit IRescue.Rescued(tokenIds[i], fantiumAthletes_admin, reason);
        }
        fantiumAthletes.rescueBatch(tokenIds, reason);

        // Verify ownership transfers
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(fantiumAthletes.ownerOf(tokenIds[i]), fantiumAthletes_admin);
        }
    }

    function test_rescueBatch_revert_unauthorized() public {
        uint256 collectionId = 1;
        uint24 quantity = 5;
        uint256 lastTokenId = mintTo(collectionId, quantity, recipient);
        uint256 firstTokenId = lastTokenId - quantity + 1;
        string memory reason = "Emergency batch rescue needed";

        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            tokenIds[i] = firstTokenId + i;
        }

        address unauthorized = makeAddr("unauthorized");

        expectMissingRole(unauthorized, fantiumAthletes.DEFAULT_ADMIN_ROLE());
        vm.prank(unauthorized);
        fantiumAthletes.rescueBatch(tokenIds, reason);
    }

    function test_rescueBatch_revert_invalidTokenId() public {
        uint256[] memory invalidTokenIds = new uint256[](1);
        invalidTokenIds[0] = 999_999;
        string memory reason = "Emergency batch rescue needed";

        vm.expectRevert("ERC721: invalid token ID");
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.rescueBatch(invalidTokenIds, reason);
    }

    // Price phases
    // ========================================================================
    function _multiPhaseCollectionData(
        uint128 p0,
        uint128 m0,
        uint128 p1,
        uint128 m1
    )
        internal
        returns (CollectionData memory data)
    {
        PricePhase[] memory phases = new PricePhase[](2);
        phases[0] = PricePhase({ price: p0, maxInvocations: m0 });
        phases[1] = PricePhase({ price: p1, maxInvocations: m1 });

        data = CollectionData({
            athleteAddress: payable(makeAddr("phaseAthlete")),
            athletePrimarySalesBPS: 9000,
            athleteSecondarySalesBPS: 500,
            fantiumSecondarySalesBPS: 200,
            launchTimestamp: block.timestamp,
            otherEarningShare1e7: 100,
            phases: phases,
            tournamentEarningShare1e7: 800
        });
    }

    function _createMintableMultiPhase(
        uint128 p0,
        uint128 m0,
        uint128 p1,
        uint128 m1
    )
        internal
        returns (uint256 collectionId)
    {
        vm.startPrank(fantiumAthletes_admin);
        collectionId = fantiumAthletes.createCollection(_multiPhaseCollectionData(p0, m0, p1, m1));
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Open);
        vm.stopPrank();
    }

    function test_createCollection_revert_phasesEmpty() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: new PricePhase[](0),
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.PhasesNotConfigured.selector, 7));
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.createCollection(data);
    }

    function test_createCollection_revert_phaseMaxInvocationsZero() public {
        PricePhase[] memory phases = new PricePhase[](2);
        phases[0] = PricePhase({ price: 50, maxInvocations: 10 });
        phases[1] = PricePhase({ price: 100, maxInvocations: 0 }); // invalid

        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            otherEarningShare1e7: 5_000_000,
            phases: phases,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.PhaseMaxInvocationsZero.selector, 1));
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.createCollection(data);
    }

    function test_createCollection_phases_seeded() public {
        uint256 collectionId = _createMintableMultiPhase(50, 3, 200, 5);
        Collection memory collection = fantiumAthletes.collections(collectionId);

        assertEq(collection.phases.length, 2);
        assertEq(collection.phases[0].price, 50);
        assertEq(collection.phases[0].maxInvocations, 3);
        assertEq(collection.phases[1].price, 200);
        assertEq(collection.phases[1].maxInvocations, 5);
    }

    function test_mintTo_phases_advancesPrice() public {
        uint128 p0 = 50;
        uint128 p1 = 200;
        uint256 collectionId = _createMintableMultiPhase(p0, 3, p1, 5);

        address buyer = makeAddr("phaseBuyer");
        uint24 phase0Quantity = 3;
        (uint256 amount0, uint256 deadline0, bytes memory signature0) =
            prepareSignedSale(collectionId, phase0Quantity, buyer);
        assertEq(amount0, uint256(p0) * phase0Quantity * 10 ** usdc.decimals());

        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.PhaseAdvanced(collectionId, 0, 1, 3);
        vm.prank(buyer);
        fantiumAthletes.mintTo(collectionId, phase0Quantity, buyer, deadline0, signature0);

        // Next mint uses phase 1 price.
        uint24 phase1Quantity = 2;
        (uint256 amount1, uint256 deadline1, bytes memory signature1) =
            prepareSignedSale(collectionId, phase1Quantity, buyer);
        assertEq(amount1, uint256(p1) * phase1Quantity * 10 ** usdc.decimals());
        vm.prank(buyer);
        fantiumAthletes.mintTo(collectionId, phase1Quantity, buyer, deadline1, signature1);

        Collection memory collection = fantiumAthletes.collections(collectionId);
        assertEq(collection.invocations, 5);
    }

    function test_mintTo_ok_crossPhaseBoundary() public {
        uint128 p0 = 50;
        uint128 p1 = 200;
        uint256 collectionId = _createMintableMultiPhase(p0, 3, p1, 5);

        address buyer = makeAddr("boundaryBuyer");
        mintTo(collectionId, 1, buyer); // phase 0 has 2 slots left

        // Buy 5: 2 from phase 0 + 3 from phase 1, each segment at its own price.
        uint24 quantity = 5;
        (uint256 amountUSDC, uint256 deadline, bytes memory signature) =
            prepareSignedSale(collectionId, quantity, buyer);
        assertEq(amountUSDC, (2 * uint256(p0) + 3 * uint256(p1)) * 10 ** usdc.decimals());

        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.Sale(collectionId, quantity, buyer, amountUSDC, 0);
        vm.expectEmit(true, false, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.PhaseAdvanced(collectionId, 0, 1, 6);
        vm.prank(buyer);
        fantiumAthletes.mintTo(collectionId, quantity, buyer, deadline, signature);

        assertEq(fantiumAthletes.collections(collectionId).invocations, 6);
    }

    function test_mintTo_ok_crossMultiplePhases() public {
        // Three phases: 2@10, 2@20, 6@30. A single purchase of 6 spans all three.
        PricePhase[] memory phases = new PricePhase[](3);
        phases[0] = PricePhase({ price: 10, maxInvocations: 2 });
        phases[1] = PricePhase({ price: 20, maxInvocations: 2 });
        phases[2] = PricePhase({ price: 30, maxInvocations: 6 });

        CollectionData memory data = _multiPhaseCollectionData(10, 2, 20, 2);
        data.phases = phases;

        vm.startPrank(fantiumAthletes_admin);
        uint256 collectionId = fantiumAthletes.createCollection(data);
        fantiumAthletes.setSaleStatus(singleCollection(collectionId), SaleStatus.Open);
        vm.stopPrank();

        address buyer = makeAddr("multiPhaseBuyer");
        uint24 quantity = 6; // 2*10 + 2*20 + 2*30 = 120
        (uint256 amountUSDC, uint256 deadline, bytes memory signature) =
            prepareSignedSale(collectionId, quantity, buyer);
        assertEq(amountUSDC, 120 * 10 ** usdc.decimals());

        // The active phase jumps from 0 straight to 2.
        vm.expectEmit(true, false, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.PhaseAdvanced(collectionId, 0, 2, 6);
        vm.prank(buyer);
        fantiumAthletes.mintTo(collectionId, quantity, buyer, deadline, signature);

        assertEq(fantiumAthletes.collections(collectionId).invocations, 6);
    }

    function test_mintTo_ok_crossPhaseToFullSellout_noPhaseAdvancedEvent() public {
        uint256 collectionId = _createMintableMultiPhase(50, 3, 200, 5);

        address buyer = makeAddr("selloutBuyer");
        uint24 quantity = 8; // entire supply in one purchase, spanning both phases
        (uint256 amountUSDC, uint256 deadline, bytes memory signature) =
            prepareSignedSale(collectionId, quantity, buyer);
        assertEq(amountUSDC, (3 * 50 + 5 * 200) * 10 ** usdc.decimals());

        vm.recordLogs();
        vm.prank(buyer);
        fantiumAthletes.mintTo(collectionId, quantity, buyer, deadline, signature);

        // Sold out: there is no active phase to advance to.
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            assertNotEq(logs[i].topics[0], IFANtiumAthletes.PhaseAdvanced.selector);
        }
        assertEq(fantiumAthletes.collections(collectionId).invocations, 8);
    }

    function test_updateCollection_phases_rewritten() public {
        uint256 collectionId = 1;
        uint24 quantity = 2;
        mintTo(collectionId, quantity, recipient); // move invocations to 2

        // Replace the single-phase config with a two-phase config. Phase 0 must cover current invocations (2).
        PricePhase[] memory phases = new PricePhase[](2);
        phases[0] = PricePhase({ price: 150, maxInvocations: 50 });
        phases[1] = PricePhase({ price: 300, maxInvocations: 50 });

        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("phaseAthleteUpdate")),
            athletePrimarySalesBPS: 6000,
            athleteSecondarySalesBPS: 500,
            fantiumSecondarySalesBPS: 200,
            launchTimestamp: block.timestamp,
            otherEarningShare1e7: 100,
            phases: phases,
            tournamentEarningShare1e7: 800
        });

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.updateCollection(collectionId, data);

        Collection memory collection = fantiumAthletes.collections(collectionId);
        assertEq(collection.phases.length, 2);
        assertEq(collection.phases[0].price, 150);
        assertEq(collection.phases[1].price, 300);
        assertEq(collection.invocations, quantity);
    }

    function test_updateCollection_ok_soldOutCollection() public {
        uint256 collectionId = 6; // collection 6 has 5 max invocations
        mintTo(collectionId, 5, recipient); // sell out the collection

        Collection memory collection = fantiumAthletes.collections(collectionId);
        assertEq(collection.invocations, 5);

        // Phases summing exactly to the current invocations are valid: the collection is sold out.
        CollectionData memory data = CollectionData({
            athleteAddress: collection.athleteAddress,
            athletePrimarySalesBPS: collection.athletePrimarySalesBPS,
            athleteSecondarySalesBPS: collection.athleteSecondarySalesBPS,
            fantiumSecondarySalesBPS: collection.fantiumSecondarySalesBPS,
            launchTimestamp: collection.launchTimestamp,
            otherEarningShare1e7: collection.otherEarningShare1e7,
            phases: singlePhase(collection.phases[0].price, 5),
            tournamentEarningShare1e7: collection.tournamentEarningShare1e7
        });

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.updateCollection(collectionId, data);

        assertEq(fantiumAthletes.collections(collectionId).phases.length, 1);
    }

    function test_mintTo_revert_allPhasesConsumed() public {
        uint256 collectionId = 6; // collection 6 has 5 max invocations
        mintTo(collectionId, 5, recipient); // sell out the collection

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory signature = signMint(recipient, fantiumAthletes.nonces(recipient), collectionId, 1, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.MAX_INVOCATIONS_REACHED)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, 1, recipient, deadline, signature);
    }

    function test_mintTo_ok_phase1Price() public {
        uint128 p1 = 200;
        uint256 collectionId = _createMintableMultiPhase(50, 3, p1, 5);

        address buyer = makeAddr("phase1Buyer");
        mintTo(collectionId, 3, buyer); // fill phase 0

        // The next mint is charged at the now-active phase 1 price.
        uint24 quantity = 1;
        (uint256 amountUSDC, uint256 deadline, bytes memory signature) =
            prepareSignedSale(collectionId, quantity, buyer);
        assertEq(amountUSDC, uint256(p1) * 10 ** usdc.decimals());

        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.Sale(collectionId, quantity, buyer, amountUSDC, 0);
        vm.prank(buyer);
        uint256 lastTokenId = fantiumAthletes.mintTo(collectionId, quantity, buyer, deadline, signature);
        assertEq(fantiumAthletes.ownerOf(lastTokenId), buyer);
    }

    // setPhases
    // ========================================================================
    function test_setPhases_ok() public {
        uint256 collectionId = 1;
        mintTo(collectionId, 2, recipient); // move invocations to 2

        PricePhase[] memory phases = new PricePhase[](2);
        phases[0] = PricePhase({ price: 150, maxInvocations: 50 });
        phases[1] = PricePhase({ price: 300, maxInvocations: 50 });

        vm.expectEmit(true, false, false, false, address(fantiumAthletes));
        emit IFANtiumAthletes.CollectionUpdated(collectionId, fantiumAthletes.collections(collectionId));
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setPhases(collectionId, phases);

        Collection memory collection = fantiumAthletes.collections(collectionId);
        assertEq(collection.phases.length, 2);
        assertEq(collection.phases[0].price, 150);
        assertEq(collection.phases[1].price, 300);
        assertEq(collection.invocations, 2);
    }

    function test_setPhases_revert_unauthorized() public {
        uint256 collectionId = 1;
        address athlete = fantiumAthletes.collections(collectionId).athleteAddress;

        expectMissingRole(athlete, fantiumAthletes.DEFAULT_ADMIN_ROLE());
        vm.prank(athlete);
        fantiumAthletes.setPhases(collectionId, singlePhase(100, 100));
    }

    function test_setPhases_revert_invalidCollectionId() public {
        uint256 invalidCollectionId = 999_999;

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.InvalidCollectionId.selector, invalidCollectionId));
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setPhases(invalidCollectionId, singlePhase(100, 100));
    }

    function test_setPhases_revert_phasesDoNotAccommodateInvocations() public {
        uint256 collectionId = 1;
        mintTo(collectionId, 10, recipient);

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.PhasesMustAccommodateInvocations.selector, 10));
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setPhases(collectionId, singlePhase(100, 9));
    }

    // initializeV12
    // ========================================================================
    function test_initializeV12_ok_seedsApplied() public {
        uint256 collectionId = 1;

        PhaseSeed[] memory seeds = new PhaseSeed[](1);
        seeds[0].collectionId = collectionId;
        seeds[0].phases = new PricePhase[](2);
        seeds[0].phases[0] = PricePhase({ price: 69, maxInvocations: 44 });
        seeds[0].phases[1] = PricePhase({ price: 118, maxInvocations: 111 });

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.initializeV12(seeds);

        Collection memory collection = fantiumAthletes.collections(collectionId);
        assertEq(collection.phases.length, 2);
        assertEq(collection.phases[0].price, 69);
        assertEq(collection.phases[0].maxInvocations, 44);
        assertEq(collection.phases[1].price, 118);
        assertEq(collection.phases[1].maxInvocations, 111);
    }

    function test_initializeV12_revert_unknownSeedCollection() public {
        PhaseSeed[] memory seeds = new PhaseSeed[](1);
        seeds[0].collectionId = 999_999;
        seeds[0].phases = singlePhase(100, 100);

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.InvalidCollectionId.selector, 999_999));
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.initializeV12(seeds);
    }

    function test_initializeV12_revert_unauthorized() public {
        PhaseSeed[] memory seeds = new PhaseSeed[](0);

        expectMissingRole(nobody, fantiumAthletes.DEFAULT_ADMIN_ROLE());
        vm.prank(nobody);
        fantiumAthletes.initializeV12(seeds);
    }

    function test_mintTo_phases_noAdvanceEventOnLastPhase() public {
        uint256 collectionId = _createMintableMultiPhase(50, 3, 200, 5);

        address buyer = makeAddr("lastPhaseBuyer");
        mintTo(collectionId, 3, buyer); // fill phase 0 (emits PhaseAdvanced)

        vm.recordLogs();
        mintTo(collectionId, 5, buyer); // fill phase 1 completely — no further phase to advance to

        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            assertNotEq(logs[i].topics[0], IFANtiumAthletes.PhaseAdvanced.selector);
        }
        assertEq(fantiumAthletes.collections(collectionId).invocations, 8);
    }
}
