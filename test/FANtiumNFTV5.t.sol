// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseTest } from "test/BaseTest.sol";
import { FANtiumNFTV5 } from "src/FANtiumNFTV5.sol";
import { IFANtiumNFT, Collection, CreateCollection } from "src/interfaces/IFANtiumNFT.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { FANtiumNFTFactory } from "test/setup/FANtiumNFTFactory.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract FANtiumNFTV5Test is BaseTest, FANtiumNFTFactory {
    function setUp() public override {
        FANtiumNFTFactory.setUp();
    }

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

    // setClaimContract
    // ========================================================================
    function testFuzz_setClaimContract_ok_manager(address claimContract) public {
        vm.startPrank(fantiumNFT_manager);
        fantiumNFT.setClaimContract(claimContract);
        vm.stopPrank();
        assertEq(fantiumNFT.claimContract(), claimContract);
    }

    function testFuzz_setClaimContract_ok_admin(address claimContract) public {
        vm.startPrank(fantiumNFT_admin);
        fantiumNFT.setClaimContract(claimContract);
        vm.stopPrank();
    }

    function testFuzz_setClaimContract_unauthorized(address nobody, address claimContract) public {
        vm.assume(
            !fantiumNFT.hasRole(fantiumNFT.MANAGER_ROLE(), nobody)
                && !fantiumNFT.hasRole(fantiumNFT.DEFAULT_ADMIN_ROLE(), nobody)
        );
        vm.startPrank(nobody);
        expectMissingRole(nobody, fantiumNFT.MANAGER_ROLE());
        fantiumNFT.setClaimContract(claimContract);
        vm.stopPrank();
    }

    // setUserManager
    // ========================================================================
    function testFuzz_setUserManager_ok(address userManager) public {
        vm.startPrank(fantiumNFT_manager);
        fantiumNFT.setUserManager(userManager);
        vm.stopPrank();
        assertEq(fantiumNFT.fantiumUserManager(), userManager);
    }

    // mintable
    // ========================================================================
    function testFuzz_mintable_ok(address recipient) public {
        vm.assume(recipient != address(0));

        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        // set user as KYCed
        vm.startPrank(fantiumUserManager_kycManager);
        fantiumUserManager.setKYC(recipient, true);
        vm.stopPrank();

        vm.startPrank(recipient);
        fantiumNFT.mintable(collectionId, quantity, recipient);
        vm.stopPrank();
    }

    function testFuzz_mintable_invalidCollectionId(address recipient) public {
        uint256 collectionId = 999_999; // collection 999_999 does not exist
        uint24 quantity = 1;
        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.InvalidCollectionId.selector, collectionId));
        fantiumNFT.mintable(collectionId, quantity, recipient);
    }

    function testFuzz_mintable_paused(address recipient) public {
        vm.assume(recipient != address(0));

        uint256 collectionId = 5; // collection 5 is paused
        uint24 quantity = 1;

        assertTrue(fantiumNFT.collections(collectionId).isPaused);

        // set user as KYCed
        vm.startPrank(fantiumUserManager_kycManager);
        fantiumUserManager.setKYC(recipient, true);
        vm.stopPrank();

        vm.startPrank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.CollectionPaused.selector, collectionId));
        fantiumNFT.mintable(collectionId, quantity, recipient);
        vm.stopPrank();
    }

    function test_mintable_notKyc(address recipient) public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        vm.startPrank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.AccountNotKYCed.selector, recipient));
        fantiumNFT.mintable(collectionId, quantity, recipient);
        vm.stopPrank();
    }

    // mintTo (standard price)
    // ========================================================================
    function testFuzz_mintTo_standardPrice_ok(address recipient) public {
        vm.assume(recipient != address(0));

        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        Collection memory collection = fantiumNFT.collections(collectionId);
        uint256 amountUSDC = collection.price * quantity;

        deal(address(usdc), recipient, amountUSDC);

        vm.prank(fantiumUserManager_kycManager);
        fantiumUserManager.setKYC(recipient, true);

        vm.startPrank(recipient);
        usdc.approve(address(fantiumNFT), amountUSDC);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, recipient);
        vm.stopPrank();

        assertEq(fantiumNFT.ownerOf(lastTokenId), recipient);
    }

    function testFuzz_mintTo_standardPrice_ok_batch(address recipient, uint24 quantity) public {
        vm.assume(recipient != address(0));

        uint256 collectionId = 1; // collection 1 is mintable
        Collection memory collection = fantiumNFT.collections(collectionId);
        uint256 reamingTokens = collection.maxInvocations - collection.invocations;
        quantity = uint24(bound(uint256(quantity), 1, reamingTokens));
        uint256 amountUSDC = collection.price * quantity;
        (uint256 fantiumRevenue, address payable fantiumAddress, uint256 athleteRevenue, address payable athleteAddress)
        = fantiumNFT.getPrimaryRevenueSplits(collectionId, amountUSDC);

        deal(address(usdc), recipient, amountUSDC);

        vm.prank(fantiumUserManager_kycManager);
        fantiumUserManager.setKYC(recipient, true);

        vm.startPrank(recipient);
        usdc.approve(fantiumNFT_proxy, amountUSDC);

        // Transfers expected
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, fantiumAddress, fantiumRevenue);
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, athleteAddress, athleteRevenue);

        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, recipient);
        uint256 firstTokenId = lastTokenId - quantity + 1;
        vm.stopPrank();

        for (uint256 tokenId = firstTokenId; tokenId <= lastTokenId; tokenId++) {
            assertEq(fantiumNFT.ownerOf(tokenId), recipient);
        }
    }

    // getPrimaryRevenueSplits
    // ========================================================================
    function testFuzz_getPrimaryRevenueSplits_ok(uint256 price) public view {
        vm.assume(0 < price && price < 1_000_000 * 10 ** usdc.decimals());
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

    function testFuzz_getPrimaryRevenueSplits_newCollection(uint256 athletePrimarySalesBPS, uint256 price) public {
        vm.assume(0 < athletePrimarySalesBPS && athletePrimarySalesBPS < 10_000);
        vm.assume(0 < price && price < 1_000_000 * 10 ** usdc.decimals());

        vm.startPrank(fantiumNFT_manager);
        uint256 collectionId = fantiumNFT.createCollection(
            CreateCollection({
                athleteAddress: fantiumNFT_athlete,
                athletePrimarySalesBPS: athletePrimarySalesBPS,
                athleteSecondarySalesBPS: 0,
                fantiumSalesAddress: fantiumNFT_treasuryPrimary,
                fantiumSecondarySalesBPS: 0,
                launchTimestamp: block.timestamp,
                maxInvocations: 1000,
                otherEarningShare1e7: 0,
                price: price,
                tournamentEarningShare1e7: 0
            })
        );
        vm.stopPrank();

        (uint256 fantiumRevenue, address payable fantiumAddress, uint256 athleteRevenue, address payable athleteAddress)
        = fantiumNFT.getPrimaryRevenueSplits(collectionId, price);

        // Verify revenue splits
        assertEq(athleteRevenue, (price * athletePrimarySalesBPS) / 10_000, "Incorrect athlete revenue");
        assertEq(fantiumRevenue, price - athleteRevenue, "Incorrect fantium revenue");

        // Verify addresses
        assertEq(fantiumAddress, fantiumNFT_treasuryPrimary, "Incorrect fantium address");
        assertEq(athleteAddress, fantiumNFT_athlete, "Incorrect athlete address");
    }

    // approve
    // ========================================================================
    function testFuzz_approve_ok(address user, address operator) public {
        vm.assume(user != address(0) && operator != address(0) && user != operator);

        uint256 collectionId = 1;
        uint24 quantity = 1;
        Collection memory collection = fantiumNFT.collections(1);
        uint256 amountUSDC = collection.price * 10 ** usdc.decimals();

        deal(address(usdc), user, amountUSDC);

        vm.prank(fantiumUserManager_kycManager);
        fantiumUserManager.setKYC(user, true);

        vm.startPrank(user);
        usdc.approve(address(fantiumNFT), amountUSDC);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, user);
        fantiumNFT.approve(operator, lastTokenId);
        assertTrue(fantiumNFT.getApproved(lastTokenId) == operator);
    }

    // setApprovalForAll
    // ========================================================================
    function testFuzz_setApprovalForAll_ok(address user, address operator) public {
        vm.prank(user);
        fantiumNFT.setApprovalForAll(operator, true);
        assertTrue(fantiumNFT.isApprovedForAll(user, operator));
    }
}
