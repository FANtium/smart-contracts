// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { FANtiumNFTV5 } from "src/FANtiumNFTV5.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "test/BaseTest.sol";
import {
    IFANtiumNFT,
    Collection,
    CollectionData,
    CollectionErrorReason,
    MintErrorReason,
    UpgradeErrorReason
} from "src/interfaces/IFANtiumNFT.sol";
import { TokenVersionUtil } from "src/utils/TokenVersionUtil.sol";
import { FANtiumNFTFactory } from "test/setup/FANtiumNFTFactory.sol";

contract FANtiumNFTV5Test is BaseTest, FANtiumNFTFactory {
    using ECDSA for bytes32;
    using Strings for uint256;

    address recipient = makeAddr("recipient");
    address nobody = makeAddr("nobody");

    function setUp() public override {
        FANtiumNFTFactory.setUp();
    }

    // version
    // ========================================================================
    // function test_version() public view {
    //     assertEq(fantiumNFT.version(), "5.0.0");
    // }

    // name
    // ========================================================================
    function test_name() public view {
        assertEq(fantiumNFT.name(), "FANtium");
    }

    // symbol
    // ========================================================================
    function test_symbol() public view {
        assertEq(fantiumNFT.symbol(), "FAN");
    }

    // setUserManager
    // ========================================================================
    function test_setUserManager_ok_manager() public {
        address newUserManager = makeAddr("newUserManager");

        vm.prank(fantiumNFT_manager);
        fantiumNFT.setUserManager(newUserManager);
        assertEq(fantiumNFT.fantiumUserManager(), newUserManager);
    }

    function test_setUserManager_ok_admin() public {
        address newUserManager = makeAddr("newUserManager");

        vm.prank(fantiumNFT_admin);
        fantiumNFT.setUserManager(newUserManager);
        assertEq(fantiumNFT.fantiumUserManager(), newUserManager);
    }

    // supportsInterface
    // ========================================================================
    function test_supportsInterface_ok() public view {
        // ERC165 interface ID
        bytes4 erc165InterfaceId = 0x01ffc9a7;
        assertTrue(fantiumNFT.supportsInterface(erc165InterfaceId), "Should support ERC165");

        // ERC721 interface ID
        bytes4 erc721InterfaceId = 0x80ac58cd;
        assertTrue(fantiumNFT.supportsInterface(erc721InterfaceId), "Should support ERC721");

        // ERC721Metadata interface ID
        bytes4 erc721MetadataInterfaceId = 0x5b5e139f;
        assertTrue(fantiumNFT.supportsInterface(erc721MetadataInterfaceId), "Should support ERC721Metadata");

        // AccessControl interface ID
        bytes4 accessControlInterfaceId = 0x7965db0b;
        assertTrue(fantiumNFT.supportsInterface(accessControlInterfaceId), "Should support AccessControl");

        // Random interface ID (should return false)
        bytes4 randomInterfaceId = 0x12345678;
        assertFalse(fantiumNFT.supportsInterface(randomInterfaceId), "Should not support random interface");
    }

    // createCollection
    // ========================================================================
    function test_createCollection_ok() public {
        CollectionData memory data = CollectionData({
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
        uint256 collectionId = fantiumNFT.createCollection(data);

        Collection memory collection = fantiumNFT.collections(collectionId);
        assertEq(collection.athleteAddress, data.athleteAddress);
        assertEq(collection.athletePrimarySalesBPS, data.athletePrimarySalesBPS);
        assertEq(collection.athleteSecondarySalesBPS, data.athleteSecondarySalesBPS);
        assertTrue(collection.exists);
        assertEq(collection.fantiumSalesAddress, data.fantiumSalesAddress);
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
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_ATHLETE_ADDRESS
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.createCollection(data);
    }

    function test_createCollection_revert_invalidPrimarySalesBPS() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 10_001, // > 100%
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_PRIMARY_SALES_BPS
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.createCollection(data);
    }

    function test_createCollection_revert_invalidSecondarySalesBPSSum() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 9000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 2000, // Sum > 100%
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_BPS_SUM)
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.createCollection(data);
    }

    function test_createCollection_revert_invalidFantiumSalesAddress() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(address(0)),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_FANTIUM_SALES_ADDRESS
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.createCollection(data);
    }

    function test_createCollection_revert_invalidMaxInvocations() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 10_000, // >= 10_000
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_MAX_INVOCATIONS
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.createCollection(data);
    }

    function test_createCollection_revert_invalidOtherEarningShare() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 10_000_001, // > 100%
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_OTHER_EARNING_SHARE
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.createCollection(data);
    }

    function test_createCollection_revert_invalidTournamentEarningShare() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 10_000_001 // > 100%
         });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_TOURNAMENT_EARNING_SHARE
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.createCollection(data);
    }

    function test_createCollection_revert_unauthorized() public {
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        address unauthorized = makeAddr("unauthorized");
        expectMissingRole(unauthorized, fantiumNFT.MANAGER_ROLE());
        vm.prank(unauthorized);
        fantiumNFT.createCollection(data);
    }

    // updateCollection
    // ========================================================================
    function test_updateCollection_ok() public {
        uint256 collectionId = 1; // Using existing collection from setup
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("newAthlete")),
            athletePrimarySalesBPS: 6000, // 60%
            athleteSecondarySalesBPS: 1500, // 15%
            fantiumSalesAddress: payable(makeAddr("newFantiumSales")),
            fantiumSecondarySalesBPS: 750, // 7.5%
            launchTimestamp: block.timestamp + 2 days,
            maxInvocations: 200, // Increased from original
            otherEarningShare1e7: 6_000_000, // 60%
            price: 200 ether,
            tournamentEarningShare1e7: 3_000_000 // 30%
         });

        Collection memory beforeCollection = fantiumNFT.collections(collectionId);

        vm.prank(fantiumNFT_manager);
        fantiumNFT.updateCollection(collectionId, data);

        Collection memory afterCollection = fantiumNFT.collections(collectionId);

        // Verify all updateable fields changed
        assertEq(afterCollection.athleteAddress, data.athleteAddress);
        assertEq(afterCollection.athletePrimarySalesBPS, data.athletePrimarySalesBPS);
        assertEq(afterCollection.athleteSecondarySalesBPS, data.athleteSecondarySalesBPS);
        assertEq(afterCollection.fantiumSalesAddress, data.fantiumSalesAddress);
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
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.InvalidCollectionId.selector, invalidCollectionId));
        vm.prank(fantiumNFT_manager);
        fantiumNFT.updateCollection(invalidCollectionId, data);
    }

    function test_updateCollection_revert_decreasedMaxInvocations() public {
        uint256 collectionId = 1;
        mintTo(collectionId, 10, recipient); // mint 10 tokens to increase invocations

        Collection memory currentCollection = fantiumNFT.collections(collectionId);

        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: currentCollection.invocations - 1, // Try to decrease below current invocations
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_MAX_INVOCATIONS
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_invalidAthleteAddress() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(address(0)),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_ATHLETE_ADDRESS
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_invalidPrimarySalesBPS() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 10_001, // > 100%
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_PRIMARY_SALES_BPS
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_invalidSecondarySalesBPSSum() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 9000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 2000, // Sum > 100%
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_BPS_SUM)
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_invalidFantiumSalesAddress() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(address(0)),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_FANTIUM_SALES_ADDRESS
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_invalidOtherEarningShare() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 10_000_001, // > 100%
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_OTHER_EARNING_SHARE
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_invalidTournamentEarningShare() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 10_000_001 // > 100%
         });

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.InvalidCollection.selector, CollectionErrorReason.INVALID_TOURNAMENT_EARNING_SHARE
            )
        );
        vm.prank(fantiumNFT_manager);
        fantiumNFT.updateCollection(collectionId, data);
    }

    function test_updateCollection_revert_unauthorized() public {
        uint256 collectionId = 1;
        CollectionData memory data = CollectionData({
            athleteAddress: payable(makeAddr("athlete")),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        address unauthorized = makeAddr("unauthorized");
        expectMissingRole(unauthorized, fantiumNFT.MANAGER_ROLE());
        vm.prank(unauthorized);
        fantiumNFT.updateCollection(collectionId, data);
    }

    // setCollectionStatus
    // ========================================================================
    function test_setCollectionStatus_ok_admin() public {
        uint256 collectionId = 1;
        bool isMintable = true;
        bool isPaused = false;

        vm.prank(fantiumNFT_admin);
        fantiumNFT.setCollectionStatus(collectionId, isMintable, isPaused);

        Collection memory collection = fantiumNFT.collections(collectionId);
        assertEq(collection.isMintable, isMintable);
        assertEq(collection.isPaused, isPaused);
    }

    function test_setCollectionStatus_ok_manager() public {
        uint256 collectionId = 1;
        bool isMintable = true;
        bool isPaused = false;

        vm.prank(fantiumNFT_manager);
        fantiumNFT.setCollectionStatus(collectionId, isMintable, isPaused);

        Collection memory collection = fantiumNFT.collections(collectionId);
        assertEq(collection.isMintable, isMintable);
        assertEq(collection.isPaused, isPaused);
    }

    function test_setCollectionStatus_ok_athlete() public {
        uint256 collectionId = 1;
        bool isMintable = true;
        bool isPaused = false;

        Collection memory collection = fantiumNFT.collections(collectionId);
        address athlete = collection.athleteAddress;

        vm.prank(athlete);
        fantiumNFT.setCollectionStatus(collectionId, isMintable, isPaused);

        collection = fantiumNFT.collections(collectionId);
        assertEq(collection.isMintable, isMintable);
        assertEq(collection.isPaused, isPaused);
    }

    function test_setCollectionStatus_revert_invalidCollectionId() public {
        uint256 invalidCollectionId = 999_999;
        bool isMintable = true;
        bool isPaused = false;

        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.InvalidCollectionId.selector, invalidCollectionId));
        vm.prank(fantiumNFT_admin);
        fantiumNFT.setCollectionStatus(invalidCollectionId, isMintable, isPaused);
    }

    function test_setCollectionStatus_revert_unauthorized() public {
        uint256 collectionId = 1;
        bool isMintable = true;
        bool isPaused = false;

        vm.expectRevert(
            abi.encodeWithSelector(
                IFANtiumNFT.AthleteOnly.selector,
                collectionId,
                nobody,
                fantiumNFT.collections(collectionId).athleteAddress
            )
        );
        vm.prank(nobody);
        fantiumNFT.setCollectionStatus(collectionId, isMintable, isPaused);
    }

    function test_setCollectionStatus_revert_wrongAthlete() public {
        // Create two collections with different athletes
        address athlete1 = makeAddr("athlete1");
        address athlete2 = makeAddr("athlete2");

        CollectionData memory data1 = CollectionData({
            athleteAddress: payable(athlete1),
            athletePrimarySalesBPS: 5000,
            athleteSecondarySalesBPS: 1000,
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
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
            fantiumSalesAddress: payable(makeAddr("fantiumSales")),
            fantiumSecondarySalesBPS: 500,
            launchTimestamp: block.timestamp + 1 days,
            maxInvocations: 100,
            otherEarningShare1e7: 5_000_000,
            price: 100 ether,
            tournamentEarningShare1e7: 2_500_000
        });

        vm.prank(fantiumNFT_manager);
        uint256 collectionId1 = fantiumNFT.createCollection(data1);

        vm.prank(fantiumNFT_manager);
        fantiumNFT.createCollection(data2);

        // Try to set status of collection1 as athlete2
        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.AthleteOnly.selector, collectionId1, athlete2, athlete1));
        vm.prank(athlete2);
        fantiumNFT.setCollectionStatus(collectionId1, true, false);
    }

    // mintable
    // ========================================================================
    function test_mintable_ok() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        // ensure that the launch timestamp has passed
        Collection memory collection = fantiumNFT.collections(collectionId);
        if (block.timestamp < collection.launchTimestamp) {
            skip(collection.launchTimestamp + 1 days);
        }

        // set user as KYCed
        vm.prank(fantiumUserManager_kycManager);
        fantiumUserManager.setKYC(recipient, true);

        vm.prank(recipient);
        fantiumNFT.mintable(collectionId, quantity, recipient);
    }

    function test_mintable_revert_invalidCollectionId() public {
        uint256 collectionId = 999_999; // collection 999_999 does not exist
        uint24 quantity = 1;

        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.InvalidCollectionId.selector, collectionId));
        fantiumNFT.mintable(collectionId, quantity, recipient);
    }

    function test_mintable_revert_notMintable() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        vm.prank(fantiumNFT_manager);
        fantiumNFT.setCollectionStatus(collectionId, false, true);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumNFT.InvalidMint.selector, MintErrorReason.COLLECTION_NOT_MINTABLE)
        );
        vm.prank(recipient);
        fantiumNFT.mintable(collectionId, quantity, recipient);
    }

    function test_mintable_revert_notLaunched() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        Collection memory collection = fantiumNFT.collections(collectionId);
        if (block.timestamp > collection.launchTimestamp) {
            rewind(collection.launchTimestamp - 1 days);
        }

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumNFT.InvalidMint.selector, MintErrorReason.COLLECTION_NOT_LAUNCHED)
        );
        fantiumNFT.mintable(collectionId, quantity, recipient);
    }

    function test_mintable_revert_notKyc() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        // ensure that the launch timestamp has passed
        Collection memory collection = fantiumNFT.collections(collectionId);
        if (block.timestamp < collection.launchTimestamp) {
            skip(collection.launchTimestamp + 1 days);
        }

        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.InvalidMint.selector, MintErrorReason.ACCOUNT_NOT_KYCED));
        vm.prank(recipient);
        fantiumNFT.mintable(collectionId, quantity, recipient);
    }

    function test_mintable_revert_paused() public {
        uint256 collectionId = 5; // collection 5 is paused
        uint24 quantity = 1;
        assertTrue(fantiumNFT.collections(collectionId).isPaused);

        // ensure that the launch timestamp has passed
        Collection memory collection = fantiumNFT.collections(collectionId);
        if (block.timestamp < collection.launchTimestamp) {
            skip(collection.launchTimestamp + 1 days);
        }

        // set user as KYCed
        vm.prank(fantiumUserManager_kycManager);
        fantiumUserManager.setKYC(recipient, true);

        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.InvalidMint.selector, MintErrorReason.COLLECTION_PAUSED));
        vm.prank(recipient);
        fantiumNFT.mintable(collectionId, quantity, recipient);
    }

    // getPrimaryRevenueSplits
    // ========================================================================
    function test_getPrimaryRevenueSplits_ok() public view {
        uint256 price = 1000 * 10 ** usdc.decimals();
        uint256 collectionId = 1; // Using collection 1 from fixtures

        (uint256 fantiumRevenue, address payable fantiumAddress, uint256 athleteRevenue, address payable athleteAddress)
        = fantiumNFT.getPrimaryRevenueSplits(collectionId, price);

        // Get collection to verify calculations
        Collection memory collection = fantiumNFT.collections(collectionId);

        // Verify revenue splits
        assertEq(athleteRevenue, (price * collection.athletePrimarySalesBPS) / 10_000, "Incorrect athlete revenue");
        assertEq(fantiumRevenue, price - athleteRevenue, "Incorrect fantium revenue");

        // Verify addresses
        assertEq(fantiumAddress, collection.fantiumSalesAddress, "Incorrect fantium address");
        assertEq(athleteAddress, collection.athleteAddress, "Incorrect athlete address");
    }

    // mintTo (standard price)
    // ========================================================================
    function test_mintTo_standardPrice_ok_single() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        prepareSale(collectionId, quantity, recipient);

        vm.prank(recipient);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, recipient);

        assertEq(fantiumNFT.ownerOf(lastTokenId), recipient);
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

        vm.prank(recipient);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, recipient);
        vm.stopPrank();

        uint256 firstTokenId = lastTokenId - quantity + 1;

        for (uint256 tokenId = firstTokenId; tokenId <= lastTokenId; tokenId++) {
            assertEq(fantiumNFT.ownerOf(tokenId), recipient);
        }

        assertEq(usdc.balanceOf(recipient), recipientBalanceBefore - amountUSDC);
    }

    // mintTo (custom price)
    // ========================================================================
    function test_mintTo_customPrice_ok_single() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        uint256 amountUSDC = 200;
        (bytes memory signature,,,,) = prepareSale(collectionId, quantity, recipient, amountUSDC);

        vm.prank(recipient);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, recipient, amountUSDC, signature);

        assertEq(fantiumNFT.ownerOf(lastTokenId), recipient);
    }

    function test_mintTo_customPrice_revert_malformedSignature() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        uint256 amountUSDC = 200;
        bytes memory malformedSignature = abi.encodePacked("malformed signature");

        vm.expectRevert("ECDSA: invalid signature length");
        vm.prank(recipient);
        fantiumNFT.mintTo(collectionId, quantity, recipient, amountUSDC, malformedSignature);
    }

    function test_mintTo_customPrice_revert_invalidSigner() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        uint256 amountUSDC = 200;

        bytes32 hash =
            keccak256(abi.encode(recipient, collectionId, quantity, amountUSDC, recipient)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(42_424_242_242_424_242, hash);
        bytes memory forgedSignature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.InvalidMint.selector, MintErrorReason.INVALID_SIGNATURE));
        vm.prank(recipient);
        fantiumNFT.mintTo(collectionId, quantity, recipient, amountUSDC, forgedSignature);
    }

    // setBaseURI
    // ========================================================================
    function test_setBaseURI_ok_manager() public {
        string memory newBaseURI = "https://new.com/";
        vm.prank(fantiumNFT_manager);
        fantiumNFT.setBaseURI(newBaseURI);
        assertEq(fantiumNFT.baseURI(), newBaseURI, "Base URI should be set");
    }

    function test_setBaseURI_ok_admin() public {
        string memory newBaseURI = "https://new.com/";
        vm.prank(fantiumNFT_admin);
        fantiumNFT.setBaseURI(newBaseURI);
        assertEq(fantiumNFT.baseURI(), newBaseURI, "Base URI should be set");
    }

    function test_setBaseURI_unauthorized() public {
        string memory newBaseURI = "https://new.com/";
        address unauthorized = makeAddr("unauthorized");

        string memory baseURIBefore = fantiumNFT.baseURI();

        expectMissingRole(unauthorized, fantiumNFT.MANAGER_ROLE());
        vm.prank(unauthorized);
        fantiumNFT.setBaseURI(newBaseURI);
        assertEq(fantiumNFT.baseURI(), baseURIBefore, "Base URI should not change");
    }

    // tokenURI
    // ========================================================================
    function test_tokenURI_ok() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);
        assertEq(
            fantiumNFT.tokenURI(tokenId), string.concat("https://app.fantium.com/api/metadata/", tokenId.toString())
        );
    }

    // upgradeTokenVersion
    // ========================================================================
    function test_upgradeTokenVersion_ok() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);

        // Verify initial ownership
        assertEq(fantiumNFT.ownerOf(tokenId), recipient);

        (, uint256 version, uint256 number,) = TokenVersionUtil.getTokenInfo(tokenId);
        // Calculate expected new token ID (version incremented by 1)
        uint256 expectedNewTokenId = TokenVersionUtil.createTokenId(collectionId, version + 1, number);

        vm.prank(fantiumNFT_tokenUpgrader);
        fantiumNFT.upgradeTokenVersion(tokenId);

        // Verify old token was burned
        vm.expectRevert("ERC721: invalid token ID");
        fantiumNFT.ownerOf(tokenId);

        // Verify new token ownership
        assertEq(fantiumNFT.ownerOf(expectedNewTokenId), recipient);
    }

    function test_upgradeTokenVersion_revert_unauthorized() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);

        address unauthorized = makeAddr("unauthorized");
        expectMissingRole(unauthorized, fantiumNFT.TOKEN_UPGRADER_ROLE());

        vm.prank(unauthorized);
        fantiumNFT.upgradeTokenVersion(tokenId);
    }

    function test_upgradeTokenVersion_revert_invalidTokenId() public {
        uint256 invalidTokenId = mintTo(1, 1, recipient) + 1;

        vm.expectRevert("ERC721: invalid token ID");
        vm.prank(fantiumNFT_tokenUpgrader);
        fantiumNFT.upgradeTokenVersion(invalidTokenId);
    }

    function test_upgradeTokenVersion_revert_invalidCollectionId() public {
        // Create a token ID with an invalid collection ID
        uint256 invalidCollectionId = 999_999;
        uint256 tokenId = TokenVersionUtil.createTokenId(invalidCollectionId, 0, 1);

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumNFT.InvalidUpgrade.selector, UpgradeErrorReason.INVALID_COLLECTION_ID)
        );
        vm.prank(fantiumNFT_tokenUpgrader);
        fantiumNFT.upgradeTokenVersion(tokenId);
    }

    function test_upgradeTokenVersion_revert_versionTooHigh() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);

        vm.startPrank(fantiumNFT_tokenUpgrader);
        // Upgrade token {TokenVersionUtil.MAX_VERSION} times
        for (uint256 i = 0; i < TokenVersionUtil.MAX_VERSION; i++) {
            tokenId = fantiumNFT.upgradeTokenVersion(tokenId);
        }

        // ... it's not possible to upgrade the token anymore
        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumNFT.InvalidUpgrade.selector, UpgradeErrorReason.VERSION_ID_TOO_HIGH)
        );
        fantiumNFT.upgradeTokenVersion(tokenId);
        vm.stopPrank();
    }

    function test_upgradeTokenVersion_revert_whenPaused() public {
        uint256 collectionId = 1;
        uint256 tokenId = mintTo(collectionId, 1, recipient);

        vm.prank(fantiumNFT_admin);
        fantiumNFT.pause();

        vm.expectRevert("Pausable: paused");
        vm.prank(fantiumNFT_tokenUpgrader);
        fantiumNFT.upgradeTokenVersion(tokenId);
    }
}
