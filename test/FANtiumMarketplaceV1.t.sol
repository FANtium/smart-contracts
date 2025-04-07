// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFANtiumMarketplace, Offer } from "../src/interfaces/IFANtiumMarketplace.sol";
import { IFANtiumNFT } from "../src/interfaces/IFANtiumNFT.sol";
import { FANtiumMarketplaceFactory } from "./setup/FANtiumMarketplaceFactory.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { BaseTest } from "test/BaseTest.sol";
import { EIP712Domain, EIP712Signer } from "test/utils/EIP712Signer.sol";

contract FANtiumMarketplaceV1Test is BaseTest, EIP712Signer, FANtiumMarketplaceFactory {
    uint256 sellerPrivateKey = 0x174e345b4a6213771e763ea717400c8f8441e155bfe7d01c29f7eeed69008e3f;
    address seller = vm.addr(sellerPrivateKey); // 0xBABEE9B1f5D556f1Ef657794729cc936B06E6b29
    address buyer = makeAddr("buyer");

    // pause
    // ========================================================================
    function test_pause_ok_admin() public {
        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.pause();
        assertTrue(fantiumMarketplace.paused());
    }

    function test_pause_revert_unauthorized() public {
        address unauthorized = makeAddr("unauthorized");

        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        vm.prank(unauthorized);
        fantiumMarketplace.pause();
    }

    // unpause
    // ========================================================================
    function test_unpause_ok_admin() public {
        // First pause the contract
        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.pause();
        assertTrue(fantiumMarketplace.paused());

        // Then unpause it
        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.unpause();
        assertFalse(fantiumMarketplace.paused());
    }

    function test_unpause_revert_unauthorized() public {
        // First pause the contract
        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.pause();
        assertTrue(fantiumMarketplace.paused());

        address unauthorized = makeAddr("unauthorized");

        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        vm.prank(unauthorized);
        fantiumMarketplace.unpause();
    }

    // setTreasury
    // ========================================================================
    function test_setTreasury_ok() public {
        address newTreasury = makeAddr("newTreasury");

        vm.expectEmit(true, true, true, true);
        emit TreasuryUpdated(newTreasury);

        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.setTreasury(newTreasury);

        assertEq(fantiumMarketplace.treasury(), newTreasury);
    }

    function test_setTreasury_revert_invalidAddress() public {
        vm.prank(fantiumMarketplace_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumMarketplace.InvalidTreasuryAddress.selector, address(0)));
        fantiumMarketplace.setTreasury(address(0));
    }

    function test_setTreasury_revert_nonOwner() public {
        address newTreasury = makeAddr("newTreasury");
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumMarketplace.setTreasury(newTreasury);
    }

    // setPaymentToken
    // ========================================================================`
    function test_setPaymentToken_ok() public {
        address newPaymentToken = makeAddr("newPaymentToken");

        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.setPaymentToken(IERC20(newPaymentToken));

        assertEq(address(fantiumMarketplace.paymentToken()), newPaymentToken);
    }

    function test_setPaymentToken_revert_nonOwner() public {
        address newPaymentToken = makeAddr("newPaymentToken");
        address currentPaymentToken = address(fantiumMarketplace.paymentToken());
        address randomUser = makeAddr("random");

        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumMarketplace.setPaymentToken(IERC20(newPaymentToken));

        assertEq(address(fantiumMarketplace.paymentToken()), currentPaymentToken);
    }

    // executeOffer
    // ========================================================================
    function test_executeOffer_ok() public {
        // mint token to seller address
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        prepareSale(collectionId, quantity, seller);
        vm.prank(seller);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, seller); // 1000000

        // seller should approve the token transfer
        vm.prank(seller);
        fantiumNFT.approve(address(fantiumMarketplace), lastTokenId);

        // mock offer
        Offer memory offer = Offer({
            seller: seller,
            tokenAddress: address(fantiumNFT),
            tokenId: lastTokenId,
            amount: 5,
            fee: 1,
            expiresAt: 1_704_067_300
        });

        bytes memory signature = typedSignPacked(sellerPrivateKey, marketplaceDomain, _hashOffer(offer));

        // top up buyer
        IERC20 paymentToken = fantiumMarketplace.paymentToken();
        deal(address(paymentToken), buyer, offer.amount);

        vm.prank(buyer);
        paymentToken.approve(address(fantiumMarketplace), offer.amount);

        vm.expectEmit(true, true, true, true);
        emit OfferExecuted(offer, buyer);

        vm.prank(buyer);
        fantiumMarketplace.executeOffer(offer, signature);

        assertEq(paymentToken.balanceOf(buyer), 0);
        assertEq(paymentToken.balanceOf(seller), (offer.amount - offer.fee));
        assertEq(paymentToken.balanceOf(fantiumMarketplace.treasury()), offer.fee);
        assertEq(fantiumNFT.ownerOf(lastTokenId), buyer);
    }

    function test_executeOffer_revert_invalidSellerSignature() public {
        Offer memory offer =
            Offer({ seller: seller, tokenAddress: address(fantiumNFT), tokenId: 1, amount: 1, fee: 1, expiresAt: 1 });

        uint256 otherPrivateKey = 0x1;
        address recoveredSigner = vm.addr(otherPrivateKey);

        bytes memory incorrectSignature = typedSignPacked(otherPrivateKey, marketplaceDomain, _hashOffer(offer));

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumMarketplace.InvalidSellerSignature.selector, recoveredSigner, offer.seller)
        );
        fantiumMarketplace.executeOffer(offer, incorrectSignature);
    }

    function test_executeOffer_revert_invalidOfferAmount() public {
        Offer memory offer = Offer({
            seller: seller,
            tokenAddress: address(fantiumNFT),
            tokenId: 1,
            amount: 0, // zero-amount offer are prohibited
            fee: 1,
            expiresAt: 1
        });

        bytes memory signature = typedSignPacked(sellerPrivateKey, marketplaceDomain, _hashOffer(offer));

        vm.expectRevert(abi.encodeWithSelector(IFANtiumMarketplace.InvalidOfferAmount.selector, offer.amount));
        fantiumMarketplace.executeOffer(offer, signature);
    }

    function test_executeOffer_revert_offerExpired() public {
        Offer memory offer =
            Offer({ seller: seller, tokenAddress: address(fantiumNFT), tokenId: 1, amount: 1, fee: 1, expiresAt: 1 });

        uint256 timeInFuture = block.timestamp + 10 days; // by this time offer has expired
        vm.warp(timeInFuture);

        bytes memory signature = typedSignPacked(sellerPrivateKey, marketplaceDomain, _hashOffer(offer));

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumMarketplace.OfferExpired.selector, offer.expiresAt, timeInFuture)
        );
        fantiumMarketplace.executeOffer(offer, signature);
    }

    function test_executeOffer_revert_sellerNotOwnerOfToken() public {
        // mint token with tokenId: 1
        address randomUser = makeAddr("random");
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        prepareSale(collectionId, quantity, randomUser);
        vm.prank(randomUser);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, randomUser); // 1000000

        // try to executeOffer using generated token id
        Offer memory offer = Offer({
            seller: seller,
            tokenAddress: address(fantiumNFT),
            tokenId: lastTokenId,
            amount: 1,
            fee: 1,
            expiresAt: 1_704_067_300
        });

        bytes memory signature = typedSignPacked(sellerPrivateKey, marketplaceDomain, _hashOffer(offer));

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumMarketplace.SellerNotOwnerOfToken.selector, offer.tokenId, offer.seller)
        );
        fantiumMarketplace.executeOffer(offer, signature);
    }
}
