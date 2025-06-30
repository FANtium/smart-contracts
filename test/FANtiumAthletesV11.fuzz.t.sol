// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {
    Collection,
    CollectionData,
    IFANtiumAthletes,
    MintRequest,
    VerificationStatus
} from "src/interfaces/IFANtiumAthletes.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumAthletesFactory } from "test/setup/FANtiumAthletesFactory.sol";

contract FANtiumAthletesV11FuzzTest is BaseTest, FANtiumAthletesFactory {
    function setUp() public override {
        FANtiumAthletesFactory.setUp();
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

        // Expect Sale event
        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.Sale(collectionId, quantity, recipient, amountUSDC, 0);

        VerificationStatus memory status = VerificationStatus({
            account: recipient,
            level: 1, // AML
            expiresAt: 1_704_067_300
        });

        MintRequest memory mintRequest = MintRequest({
            collectionId: collectionId,
            quantity: quantity,
            recipient: recipient,
            amount: amountUSDC,
            verificationStatus: status
        });

        // create signature
        bytes memory signature = typedSignPacked(
            fantiumAthletes_signerKey, athletesDomain, _hashVerificationStatus(mintRequest.verificationStatus)
        );

        vm.prank(recipient);
        uint256 lastTokenId = fantiumAthletes.mintTo(mintRequest, signature);

        assertEq(fantiumAthletes.ownerOf(lastTokenId), recipient);
        assertEq(usdc.balanceOf(recipient), recipientBalanceBefore - amountUSDC);
        assertEq(usdc.balanceOf(fantiumAddress), fantiumBalanceBefore + fantiumRevenue);
        assertEq(usdc.balanceOf(athleteAddress), athleteBalanceBefore + athleteRevenue);
    }

    function testFuzz_mintTo_standardPrice_ok_batch(address recipient, uint24 quantity) public {
        vm.assume(recipient != address(0));

        uint256 collectionId = 1; // collection 1 is mintable
        quantity = uint24(
            bound(
                uint256(quantity),
                1,
                fantiumAthletes.collections(collectionId).maxInvocations
                    - fantiumAthletes.collections(collectionId).invocations
            )
        );

        (
            uint256 amountUSDC,
            uint256 fantiumRevenue,
            address payable fantiumAddress,
            uint256 athleteRevenue,
            address payable athleteAddress
        ) = prepareSale(collectionId, quantity, recipient);
        vm.assume(recipient != fantiumAddress && recipient != athleteAddress);

        // Store initial balances
        uint256[3] memory balancesBefore =
            [usdc.balanceOf(recipient), usdc.balanceOf(fantiumAddress), usdc.balanceOf(athleteAddress)];

        // Expect ERC20 Transfer events
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, fantiumAddress, fantiumRevenue);
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, athleteAddress, athleteRevenue);

        // Expect Sale event
        vm.expectEmit(true, true, false, true, address(fantiumAthletes));
        emit IFANtiumAthletes.Sale(collectionId, quantity, recipient, amountUSDC, 0);

        VerificationStatus memory status = VerificationStatus({
            account: recipient,
            level: 1, // AML
            expiresAt: 1_704_067_300
        });

        MintRequest memory mintRequest = MintRequest({
            collectionId: collectionId,
            quantity: quantity,
            recipient: recipient,
            amount: amountUSDC,
            verificationStatus: status
        });

        // create signature
        bytes memory signature = typedSignPacked(
            fantiumAthletes_signerKey, athletesDomain, _hashVerificationStatus(mintRequest.verificationStatus)
        );

        vm.prank(recipient);
        uint256 lastTokenId = fantiumAthletes.mintTo(mintRequest, signature);

        // Verify ownership
        for (uint256 i = 0; i < quantity; i++) {
            assertEq(fantiumAthletes.ownerOf(lastTokenId - i), recipient);
        }

        // Verify ERC20 transfers
        assertEq(usdc.balanceOf(recipient), balancesBefore[0] - amountUSDC);
        assertEq(usdc.balanceOf(fantiumAddress), balancesBefore[1] + fantiumRevenue);
        assertEq(usdc.balanceOf(athleteAddress), balancesBefore[2] + athleteRevenue);
    }

    // getPrimaryRevenueSplits
    // ========================================================================
    function testFuzz_getPrimaryRevenueSplits_ok(uint256 price) public view {
        vm.assume(0 < price && price < 1_000_000 * 10 ** usdc.decimals());
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

    function testFuzz_getPrimaryRevenueSplits_newCollection(uint256 athletePrimarySalesBPS, uint256 price) public {
        vm.assume(0 < athletePrimarySalesBPS && athletePrimarySalesBPS < 10_000);
        vm.assume(0 < price && price < 1_000_000 * 10 ** usdc.decimals());

        vm.startPrank(fantiumAthletes_admin);
        uint256 collectionId = fantiumAthletes.createCollection(
            CollectionData({
                athleteAddress: fantiumAthletes_athlete,
                athletePrimarySalesBPS: athletePrimarySalesBPS,
                athleteSecondarySalesBPS: 0,
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
        = fantiumAthletes.getPrimaryRevenueSplits(collectionId, price);

        // Verify revenue splits
        assertEq(athleteRevenue, (price * athletePrimarySalesBPS) / 10_000, "Incorrect athlete revenue");
        assertEq(fantiumRevenue, price - athleteRevenue, "Incorrect fantium revenue");

        // Verify addresses
        assertEq(fantiumAddress, fantiumAthletes_treasuryPrimary, "Incorrect fantium address");
        assertEq(athleteAddress, fantiumAthletes_athlete, "Incorrect athlete address");
    }
}
