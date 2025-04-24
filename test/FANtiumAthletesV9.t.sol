// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {
    Collection,
    CollectionData,
    CollectionErrorReason,
    IFANtiumAthletes,
    MintErrorReason,
    UpgradeErrorReason
} from "src/interfaces/IFANtiumAthletes.sol";
import { IFANtiumUserManager } from "src/interfaces/IFANtiumUserManager.sol";
import { IRescue } from "src/interfaces/IRescue.sol";
import { TokenVersionUtil } from "src/utils/TokenVersionUtil.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumAthletesFactory } from "test/setup/FANtiumAthletesFactory.sol";

contract FANtiumAthletesV9Test is BaseTest, FANtiumAthletesFactory {
    using ECDSA for bytes32;
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

    // setUserManager
    // ========================================================================
    function test_setUserManager_ok_manager() public {
        address newUserManager = makeAddr("newUserManager");

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setUserManager(IFANtiumUserManager(newUserManager));
        assertEq(address(fantiumAthletes.userManager()), newUserManager);
    }

    function test_setUserManager_ok_admin() public {
        address newUserManager = makeAddr("newUserManager");

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setUserManager(IFANtiumUserManager(newUserManager));
        assertEq(address(fantiumAthletes.userManager()), newUserManager);
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
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000, // 50%
            price: 100 ether,
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
        assertFalse(collection.isMintable);
        assertTrue(collection.isPaused);
        assertEq(collection.launchTimestamp, data.launchTimestamp);
        assertEq(collection.maxInvocations, data.maxInvocations);
        assertEq(collection.otherEarningShare1e7, data.otherEarningShare1e7);
        assertEq(collection.price, data.price);
        assertEq(collection.tournamentEarningShare1e7, data.tournamentEarningShare1e7);
    }

    function test_createCollection_revert_invalidAthleteAddress() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(address(0)),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
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
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
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
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
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
            maxInvocations: 10_000, // >= 10_000
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
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
            maxInvocations: 100,
            otherEarningShare1e7: 10_000_001, // > 100%
            price: 100 ether,
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
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
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
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
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
            maxInvocations: 200, // Increased from original
            otherEarningShare1e7: 6_000_000, // 60%
            price: 200 ether,
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
        assertEq(afterCollection.maxInvocations, data.maxInvocations);
        assertEq(afterCollection.otherEarningShare1e7, data.otherEarningShare1e7);
        assertEq(afterCollection.price, data.price);
        assertEq(afterCollection.tournamentEarningShare1e7, data.tournamentEarningShare1e7);

        // Verify non-updateable fields remained unchanged
        assertEq(afterCollection.exists, beforeCollection.exists);
        assertEq(afterCollection.invocations, beforeCollection.invocations);
        assertEq(afterCollection.isMintable, beforeCollection.isMintable);
        assertEq(afterCollection.isPaused, beforeCollection.isPaused);
    }

    function test_updateCollection_revert_invalidCollectionId() public {
        uint256 invalidCollectionId = 999_999;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.InvalidCollectionId.selector, invalidCollectionId));
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.updateCollection(invalidCollectionId, data);
    }

    function test_updateCollection_revert_decreasedMaxInvocations() public {
        uint256 collectionId = 1;
        mintTo(collectionId, 10, recipient); // mint 10 tokens to increase invocations

        Collection memory currentCollection = fantiumAthletes.collections(collectionId);

        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: currentCollection.invocations - 1, // Try to decrease below current invocations
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.InvalidCollection.selector, CollectionErrorReason.INVALID_MAX_INVOCATIONS
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
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
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
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
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
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
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
            maxInvocations: 100,
            otherEarningShare1e7: 10_000_001, // > 100%
            price: 100 ether,
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
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
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
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        address unauthorized = makeAddr("unauthorized");
        expectMissingRole(unauthorized, fantiumAthletes.DEFAULT_ADMIN_ROLE());
        vm.prank(unauthorized);
        fantiumAthletes.updateCollection(collectionId, data);
    }

    // setCollectionStatus
    // ========================================================================
    function test_setCollectionStatus_ok_admin() public {
        uint256 collectionId = 1;
        bool isMintable = true;
        bool isPaused = false;

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setCollectionStatus(collectionId, isMintable, isPaused);

        Collection memory collection = fantiumAthletes.collections(collectionId);
        assertEq(collection.isMintable, isMintable);
        assertEq(collection.isPaused, isPaused);
    }

    function test_setCollectionStatus_ok_manager() public {
        uint256 collectionId = 1;
        bool isMintable = true;
        bool isPaused = false;

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setCollectionStatus(collectionId, isMintable, isPaused);

        Collection memory collection = fantiumAthletes.collections(collectionId);
        assertEq(collection.isMintable, isMintable);
        assertEq(collection.isPaused, isPaused);
    }

    function test_setCollectionStatus_ok_athlete() public {
        uint256 collectionId = 1;
        bool isMintable = true;
        bool isPaused = false;

        Collection memory collection = fantiumAthletes.collections(collectionId);
        address athlete = collection.athleteAddress;

        vm.prank(athlete);
        fantiumAthletes.setCollectionStatus(collectionId, isMintable, isPaused);

        collection = fantiumAthletes.collections(collectionId);
        assertEq(collection.isMintable, isMintable);
        assertEq(collection.isPaused, isPaused);
    }

    function test_setCollectionStatus_revert_invalidCollectionId() public {
        uint256 invalidCollectionId = 999_999;
        bool isMintable = true;
        bool isPaused = false;

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.InvalidCollectionId.selector, invalidCollectionId));
        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setCollectionStatus(invalidCollectionId, isMintable, isPaused);
    }

    function test_setCollectionStatus_revert_unauthorized() public {
        uint256 collectionId = 1;
        bool isMintable = true;
        bool isPaused = false;

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumAthletes.AthleteOnly.selector,
                collectionId,
                nobody,
                fantiumAthletes.collections(collectionId).athleteAddress
            )
        );
        vm.prank(nobody);
        fantiumAthletes.setCollectionStatus(collectionId, isMintable, isPaused);
    }

    function test_setCollectionStatus_revert_wrongAthlete() public {
        // Create two collections with different athletes
        address athlete1 = makeAddr("athlete1");
        address athlete2 = makeAddr("athlete2");

        CollectionData memory data1 = CollectionData({
            athleteAddress: payable(athlete1),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        CollectionData memory data2 = CollectionData({
            athleteAddress: payable(athlete2),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
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
        fantiumAthletes.setCollectionStatus(collectionId1, true, false);
    }

    // mintable
    // ========================================================================
    function test_mintable_ok() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        // ensure that the launch timestamp has passed
        Collection memory collection = fantiumAthletes.collections(collectionId);
        if (block.timestamp < collection.launchTimestamp) {
            skip(collection.launchTimestamp + 1 days);
        }

        // set user as KYCed
        vm.prank(userManager_kycManager);
        userManager.setKYC(recipient, true);

        vm.prank(recipient);
        fantiumAthletes.mintable(collectionId, quantity, recipient);
    }

    function test_mintable_revert_invalidCollectionId() public {
        uint256 collectionId = 999_999; // collection 999_999 does not exist
        uint24 quantity = 1;

        vm.expectRevert(abi.encodeWithSelector(IFANtiumAthletes.InvalidCollectionId.selector, collectionId));
        fantiumAthletes.mintable(collectionId, quantity, recipient);
    }

    function test_mintable_revert_notMintable() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        vm.prank(fantiumAthletes_admin);
        fantiumAthletes.setCollectionStatus(collectionId, false, true);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.COLLECTION_NOT_MINTABLE)
        );
        vm.prank(recipient);
        fantiumAthletes.mintable(collectionId, quantity, recipient);
    }

    function test_mintable_revert_notLaunched() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        Collection memory collection = fantiumAthletes.collections(collectionId);
        if (block.timestamp > collection.launchTimestamp) {
            rewind(collection.launchTimestamp - 1 days);
        }

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.COLLECTION_NOT_LAUNCHED)
        );
        fantiumAthletes.mintable(collectionId, quantity, recipient);
    }

    function test_mintable_revert_notKyc() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        // ensure that the launch timestamp has passed
        Collection memory collection = fantiumAthletes.collections(collectionId);
        if (block.timestamp < collection.launchTimestamp) {
            skip(collection.launchTimestamp + 1 days);
        }

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.ACCOUNT_NOT_KYCED)
        );
        vm.prank(recipient);
        fantiumAthletes.mintable(collectionId, quantity, recipient);
    }

    function test_mintable_revert_paused() public {
        uint256 collectionId = 5; // collection 5 is paused
        uint24 quantity = 1;
        assertTrue(fantiumAthletes.collections(collectionId).isPaused);

        // ensure that the launch timestamp has passed
        Collection memory collection = fantiumAthletes.collections(collectionId);
        if (block.timestamp < collection.launchTimestamp) {
            skip(collection.launchTimestamp + 1 days);
        }

        // set user as KYCed
        vm.prank(userManager_kycManager);
        userManager.setKYC(recipient, true);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.COLLECTION_PAUSED)
        );
        vm.prank(recipient);
        fantiumAthletes.mintable(collectionId, quantity, recipient);
    }

    // getPrimaryRevenueSplits
    // ========================================================================
    function test_getPrimaryRevenueSplits_ok() public view {
        uint256 price = 1000 * 10 ** usdc.decimals();
        uint256 collectionId = 1; // Using collection 1 from fixtures

        (uint256 fantiumRevenue, address payable fantiumAddress, uint256 athleteRevenue, address payable athleteAddress)
        = fantiumAthletes.getPrimaryRevenueSplits(collectionId, price);

        // Get collection to verify calculations
        Collection memory collection = fantiumAthletes.collections(collectionId);

        // Verify revenue splits
        assertEq(athleteRevenue, (price * collection.athletePrimarySalesBPS) / 10_000, "Incorrect athlete revenue");
        assertEq(fantiumRevenue, price - athleteRevenue, "Incorrect fantium revenue");

        // Verify addresses
        assertEq(fantiumAddress, fantiumAthletes.treasury(), "Incorrect treasury address");
        assertEq(athleteAddress, collection.athleteAddress, "Incorrect athlete address");
    }

    // mintTo (standard price)
    // ========================================================================
    function test_mintTo_standardPrice_ok_single() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        (uint256 amountUSDC,,,,) = prepareSale(collectionId, quantity, recipient);

        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.Sale(collectionId, quantity, recipient, amountUSDC, 0);
        vm.prank(recipient);
        uint256 lastTokenId = fantiumAthletes.mintTo(collectionId, quantity, recipient);

        assertEq(fantiumAthletes.ownerOf(lastTokenId), recipient);
    }

    function test_mintTo_standardPrice_ok_batch() public {
        uint24 quantity = 10;
        uint256 collectionId = 1; // collection 1 is mintable

        (
            uint256 amountUSDC,
            uint256 fantiumRevenue,
            address payable fantiumAddress,
            uint256 athleteRevenue,
            address payable athleteAddress
        ) = prepareSale(collectionId, quantity, recipient);
        uint256 recipientBalanceBefore = usdc.balanceOf(recipient);

        // Transfers expected
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, fantiumAddress, fantiumRevenue);
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, athleteAddress, athleteRevenue);

        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.Sale(collectionId, quantity, recipient, amountUSDC, 0);
        vm.prank(recipient);
        uint256 lastTokenId = fantiumAthletes.mintTo(collectionId, quantity, recipient);
        vm.stopPrank();

        uint256 firstTokenId = lastTokenId - quantity + 1;

        for (uint256 tokenId = firstTokenId; tokenId <= lastTokenId; tokenId++) {
            assertEq(fantiumAthletes.ownerOf(tokenId), recipient);
        }

        assertEq(usdc.balanceOf(recipient), recipientBalanceBefore - amountUSDC);
    }

    // mintTo (custom price)
    // ========================================================================
    function test_mintTo_customPrice_ok_single() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        uint256 amountUSDC = 74 * 10 ** usdc.decimals(); // normal price is 99 USDC
        (bytes memory signature,,,,,) = prepareSale(collectionId, quantity, recipient, amountUSDC);

        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.Sale(collectionId, quantity, recipient, amountUSDC, 25 * 10 ** usdc.decimals());
        vm.prank(recipient);
        uint256 lastTokenId = fantiumAthletes.mintTo(collectionId, quantity, recipient, amountUSDC, signature);

        assertEq(fantiumAthletes.ownerOf(lastTokenId), recipient);
    }

    function test_mintTo_customPrice_revert_malformedSignature() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        uint256 amountUSDC = 200;
        bytes memory malformedSignature = abi.encodePacked("malformed signature");

        vm.expectRevert("ECDSA: invalid signature length");
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, quantity, recipient, amountUSDC, malformedSignature);
    }

    function test_mintTo_customPrice_revert_invalidSigner() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        uint256 amountUSDC = 200;

        bytes32 hash =
            keccak256(abi.encode(recipient, collectionId, quantity, amountUSDC, recipient)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(42_424_242_242_424_242, hash);
        bytes memory forgedSignature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.INVALID_SIGNATURE)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, quantity, recipient, amountUSDC, forgedSignature);
    }

    function test_mintTo_revert_invalidNonce() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        uint256 amountUSDC = 200;
        (bytes memory signature,,,,,) = prepareSale(collectionId, quantity, recipient, amountUSDC);

        // First mint pass, and nonce is incremented
        vm.prank(recipient);
        uint256 lastTokenId = fantiumAthletes.mintTo(collectionId, quantity, recipient, amountUSDC, signature);
        assertEq(fantiumAthletes.ownerOf(lastTokenId), recipient);

        // Second mint fails, because nonce is incremented
        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumAthletes.InvalidMint.selector, MintErrorReason.INVALID_SIGNATURE)
        );
        vm.prank(recipient);
        fantiumAthletes.mintTo(collectionId, quantity, recipient, amountUSDC, signature);
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
}
