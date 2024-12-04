// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseTest } from "test/BaseTest.sol";
import { FANtiumNFTV5 } from "src/FANtiumNFTV5.sol";
import { IFANtiumNFT, Collection, CollectionData } from "src/interfaces/IFANtiumNFT.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { FANtiumNFTFactory } from "test/setup/FANtiumNFTFactory.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract FANtiumNFTV5FuzzTest is BaseTest, FANtiumNFTFactory {
    function setUp() public override {
        FANtiumNFTFactory.setUp();
    }

    // mintTo (standard price)
    // ========================================================================
    function testFuzz_mintTo_standardPrice_ok(address recipient) public {
        vm.assume(recipient != address(0));

        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        (
            uint256 amountUSDC,
            uint256 fantiumRevenue,
            address payable fantiumAddress,
            uint256 athleteRevenue,
            address payable athleteAddress
        ) = prepareSale(collectionId, quantity, recipient);
        vm.assume(recipient != fantiumAddress && recipient != athleteAddress);

        uint256 recipientBalanceBefore = usdc.balanceOf(recipient);
        uint256 fantiumBalanceBefore = usdc.balanceOf(fantiumAddress);
        uint256 athleteBalanceBefore = usdc.balanceOf(athleteAddress);

        vm.prank(recipient);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, recipient);

        assertEq(fantiumNFT.ownerOf(lastTokenId), recipient);
        assertEq(usdc.balanceOf(recipient), recipientBalanceBefore - amountUSDC);
        assertEq(usdc.balanceOf(fantiumAddress), fantiumBalanceBefore + fantiumRevenue);
        assertEq(usdc.balanceOf(athleteAddress), athleteBalanceBefore + athleteRevenue);
    }

    function testFuzz_mintTo_standardPrice_ok_batch(address recipient, uint24 quantity) public {
        vm.assume(recipient != address(0));

        uint256 collectionId = 1; // collection 1 is mintable
        Collection memory collection = fantiumNFT.collections(collectionId);
        quantity = uint24(bound(uint256(quantity), 1, collection.maxInvocations - collection.invocations));

        (
            uint256 amountUSDC,
            uint256 fantiumRevenue,
            address payable fantiumAddress,
            uint256 athleteRevenue,
            address payable athleteAddress
        ) = prepareSale(collectionId, quantity, recipient);
        vm.assume(recipient != fantiumAddress && recipient != athleteAddress);

        uint256 recipientBalanceBefore = usdc.balanceOf(recipient);
        uint256 fantiumBalanceBefore = usdc.balanceOf(fantiumAddress);
        uint256 athleteBalanceBefore = usdc.balanceOf(athleteAddress);

        // Expect ERC20 Transfer events
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, fantiumAddress, fantiumRevenue);
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, athleteAddress, athleteRevenue);

        vm.prank(recipient);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, recipient);
        uint256 firstTokenId = lastTokenId - quantity + 1;

        // Verify ownership
        for (uint256 tokenId = firstTokenId; tokenId <= lastTokenId; tokenId++) {
            assertEq(fantiumNFT.ownerOf(tokenId), recipient);
        }

        // Verify ERC20 transfers
        assertEq(usdc.balanceOf(recipient), recipientBalanceBefore - amountUSDC);
        assertEq(usdc.balanceOf(fantiumAddress), fantiumBalanceBefore + fantiumRevenue);
        assertEq(usdc.balanceOf(athleteAddress), athleteBalanceBefore + athleteRevenue);
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
            CollectionData({
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
}
