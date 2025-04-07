// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFANtiumMarketplace, Offer } from "../src/interfaces/IFANtiumMarketplace.sol";

import { IFANtiumNFT } from "../src/interfaces/IFANtiumNFT.sol";
import { FANtiumMarketplaceFactory } from "./setup/FANtiumMarketplaceFactory.t.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { BaseTest } from "test/BaseTest.sol";

/* every time your modify the contract -> contract bytecode changes -> contract address during test execution changes.
    To get contract address, use the following:
    console.log("address of Marketplace contract", address(fantiumMarketplace));
*/
contract FANtiumMarketplaceV1Test is BaseTest, FANtiumMarketplaceFactory {
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

    // setTreasuryAddress
    // ========================================================================
    function test_setTreasuryAddress_ok() public {
        address newTreasury = makeAddr("newTreasury");
        vm.prank(fantiumMarketplace_admin);
        vm.expectEmit(true, true, true, true);
        emit TreasuryAddressUpdate(newTreasury);
        fantiumMarketplace.setTreasuryAddress(newTreasury);
        assertEq(fantiumMarketplace.treasury(), newTreasury);
    }

    function test_setTreasuryAddress_revert_invalidAddress() public {
        vm.prank(fantiumMarketplace_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumMarketplace.InvalidTreasuryAddress.selector, address(0)));
        fantiumMarketplace.setTreasuryAddress(address(0));
    }

    function test_setTreasuryAddress_revert_sameTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");
        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.setTreasuryAddress(newTreasury);
        assertEq(fantiumMarketplace.treasury(), newTreasury);
        vm.prank(fantiumMarketplace_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumMarketplace.TreasuryAddressAlreadySet.selector, newTreasury));
        fantiumMarketplace.setTreasuryAddress(newTreasury);
    }

    function test_setTreasuryAddress_revert_nonOwner() public {
        address newTreasury = makeAddr("newTreasury");
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumMarketplace.setTreasuryAddress(newTreasury);
    }

    // setFANtiumNFTContract
    // ========================================================================
    function test_setFANtiumNFTContract_ok() public {
        address newFANtiumNFTContract = makeAddr("newFANtiumNFTContract");

        vm.startPrank(fantiumMarketplace_admin);

        // Initially, the NFT contract should be address(0)
        assertEq(address(fantiumMarketplace.nftContract()), address(0));

        // set new address
        fantiumMarketplace.setFANtiumNFTContract(IFANtiumNFT(newFANtiumNFTContract));

        assertEq(address(fantiumMarketplace.nftContract()), newFANtiumNFTContract);

        vm.stopPrank();
    }

    function test_setFANtiumNFTContract_revert_nonOwner() public {
        address newFANtiumNFTContract = makeAddr("newFANtiumNFTContract");
        address randomUser = makeAddr("random");

        vm.startPrank(randomUser);

        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        // try to set new address
        fantiumMarketplace.setFANtiumNFTContract(IFANtiumNFT(newFANtiumNFTContract));

        vm.stopPrank();
    }

    // setUsdcContractAddress
    // ========================================================================`
    function test_setUsdcContractAddress_ok() public {
        address newUSDCAddress = makeAddr("newUSDCContract");

        vm.startPrank(fantiumMarketplace_admin);

        // Initial usdcContractAddress is set during test setup()

        // set new address
        fantiumMarketplace.setUsdcContractAddress(newUSDCAddress);

        assertEq(fantiumMarketplace.usdcContractAddress(), newUSDCAddress);

        vm.stopPrank();
    }

    function test_setUsdcContractAddress_revert_nonOwner() public {
        address newUSDCAddress = makeAddr("newUSDCContract");
        address randomUser = makeAddr("random");

        vm.startPrank(randomUser);

        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        // try to set new address
        fantiumMarketplace.setUsdcContractAddress(newUSDCAddress);

        vm.stopPrank();
    }

    // executeOffer
    // ========================================================================
    function test_executeOffer_ok() public {
        // 1. test setup
        // set fantiumNFT contract
        vm.startPrank(fantiumMarketplace_admin);
        fantiumMarketplace.setFANtiumNFTContract(fantiumNFT);
        assertEq(address(fantiumMarketplace.nftContract()), address(fantiumNFT));

        // set treasury
        address treasury = makeAddr("treasury");
        fantiumMarketplace.setTreasuryAddress(treasury);
        assertEq(address(fantiumMarketplace.treasury()), treasury);
        vm.stopPrank();

        // mint token to seller address
        address seller = 0xAAAAb8A44732De44021aac698944Ec1D47cF9031;
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
            tokenAddress: address(fantiumNFT), // 0xc7183455a4C133Ae270771860664b6B7ec320bB1
            tokenId: lastTokenId,
            amount: 5,
            fee: 1,
            expiresAt: 1_704_067_300
        });

        // this signature is generated by the script from lab based on the above Offer
        bytes memory signature =
            hex"83fd858c6b36aece4c8e7fc86f6c2c4cdeae2ad271b07a40422a3bf18ea1a4be7ac86c9c243bf89259caaee39ef691fe8fb7c5487ff54aa13f79a0775231be031c";

        // top up buyer
        address usdcAddress = fantiumMarketplace.usdcContractAddress();
        address buyer = makeAddr("buyer"); // 0x0fF93eDfa7FB7Ad5E962E4C0EdB9207C03a0fe02
        uint8 tokenDecimals = IERC20MetadataUpgradeable(usdcAddress).decimals();
        uint256 expectedAmount = offer.amount * 10 ** tokenDecimals;
        deal(usdcAddress, buyer, expectedAmount);
        // verify buyer has been topped up
        assertEq(IERC20Upgradeable(usdcAddress).balanceOf(buyer), expectedAmount);
        // approve allowance
        vm.prank(buyer);
        IERC20Upgradeable(usdcAddress).approve(address(fantiumMarketplace), expectedAmount);

        vm.prank(buyer);
        vm.expectEmit(true, true, true, true); // check that event was emitted
        emit OfferExecuted(offer, buyer);
        fantiumMarketplace.executeOffer(offer, signature);

        // 3. check: Buyer sent USDC to seller
        assertEq(IERC20Upgradeable(usdcAddress).balanceOf(buyer), 0);
        assertEq(IERC20Upgradeable(usdcAddress).balanceOf(seller), (offer.amount - offer.fee) * 10 ** tokenDecimals);

        // 4. check: Buyer sends USDC to treasury (our fee)
        assertEq(IERC20Upgradeable(usdcAddress).balanceOf(treasury), offer.fee * 10 ** tokenDecimals);

        // 5. check: Seller sent NFT to buyer
        assertEq(fantiumNFT.ownerOf(lastTokenId), buyer);
    }

    function test_executeOffer_revert_InvalidSellerSignature() public {
        Offer memory offer = Offer({
            seller: 0xAAAAb8A44732De44021aac698944Ec1D47cF9031,
            tokenAddress: 0x999999cf1046e68e36E1aA2E0E07105eDDD1f08E,
            tokenId: 1,
            amount: 1,
            fee: 1,
            expiresAt: 1
        });

        // random signature
        bytes memory incorrectSignature =
            hex"33f3d2749d8fcaa747346be24427629790f8c5f6c661e5f4056163a40fea4f6e77efdc42b786e935d9f0ac897b57e7cd99aec8845af2fb17b3a87af1730401a31c";
        address recoveredSigner = 0x89cdc667f1dB3C44f2B4eeD501e0bf56E058cBD6; // this signer is extracted from
            // incorrectSignature

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumMarketplace.InvalidSellerSignature.selector, recoveredSigner, offer.seller)
        );
        fantiumMarketplace.executeOffer(offer, incorrectSignature);
    }

    function test_executeOffer_revert_InvalidOfferAmount() public {
        Offer memory offer = Offer({
            seller: 0xAAAAb8A44732De44021aac698944Ec1D47cF9031,
            tokenAddress: 0x999999cf1046e68e36E1aA2E0E07105eDDD1f08E,
            tokenId: 1,
            amount: 0, // wrong amount
            fee: 1,
            expiresAt: 1
        });

        // this signature is generated by the script from lab
        bytes memory signature =
            hex"86908e3fd199c480e0fdf925666049e4d32c1928a67350bc5b5ea50ae049ee1b50e46daeb22b5000e848d694e63b84831e2e101518436fd22fc279bd64e255a01b";

        vm.expectRevert(abi.encodeWithSelector(IFANtiumMarketplace.InvalidOfferAmount.selector, offer.amount));
        fantiumMarketplace.executeOffer(offer, signature);
    }

    function test_executeOffer_revert_OfferExpired() public {
        Offer memory offer = Offer({
            seller: 0xAAAAb8A44732De44021aac698944Ec1D47cF9031,
            tokenAddress: 0x999999cf1046e68e36E1aA2E0E07105eDDD1f08E,
            tokenId: 1,
            amount: 1,
            fee: 1,
            expiresAt: 1
        });

        uint256 timeInFuture = block.timestamp + 10 days; // by this time offer has expired

        // warp time to the future
        vm.warp(timeInFuture); // by this time offer has expired

        // this signature is generated by the script from lab
        bytes memory signature =
            hex"5c22807b92eaf37f5531f691345249739428ff31d0e941891d6daa80addb1ac904e9b632b865939cd160f906aa97d6e6d22f23d676c03b7ffdcd5c167eb7231b1c";

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumMarketplace.OfferExpired.selector, offer.expiresAt, timeInFuture)
        );
        fantiumMarketplace.executeOffer(offer, signature);
    }

    function test_executeOffer_revert_NFTContractNotSet() public {
        Offer memory offer = Offer({
            seller: 0xAAAAb8A44732De44021aac698944Ec1D47cF9031,
            tokenAddress: 0x999999cf1046e68e36E1aA2E0E07105eDDD1f08E,
            tokenId: 1,
            amount: 1,
            fee: 1,
            expiresAt: 1
        });

        // this signature is generated by the script from lab
        bytes memory signature =
            hex"5c22807b92eaf37f5531f691345249739428ff31d0e941891d6daa80addb1ac904e9b632b865939cd160f906aa97d6e6d22f23d676c03b7ffdcd5c167eb7231b1c";

        vm.expectRevert(abi.encodeWithSelector(IFANtiumMarketplace.NFTContractNotSet.selector));
        fantiumMarketplace.executeOffer(offer, signature);
    }

    function test_executeOffer_revert_SellerNotOwnerOfToken() public {
        // test setup
        // set up fantiumNFT contract
        vm.startPrank(fantiumMarketplace_admin);
        fantiumMarketplace.setFANtiumNFTContract(fantiumNFT);
        assertEq(address(fantiumMarketplace.nftContract()), address(fantiumNFT));
        vm.stopPrank();

        // mint token with tokenId: 1
        address randomUser = makeAddr("random");
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        prepareSale(collectionId, quantity, randomUser);
        vm.prank(randomUser);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, randomUser); // 1000000

        // try to executeOffer using generated token id
        Offer memory offer = Offer({
            seller: 0xAAAAb8A44732De44021aac698944Ec1D47cF9031,
            tokenAddress: address(fantiumNFT), // 0xc7183455a4C133Ae270771860664b6B7ec320bB1
            tokenId: lastTokenId,
            amount: 1,
            fee: 1,
            expiresAt: 1_704_067_300
        });

        // this signature is generated by the script from lab based on the above Offer
        bytes memory signature =
            hex"dda7a3e2f44dc943aaf62ef6c6340cb98d55d88db9803cfcff26a7b6adaea02667beb089ca5483c84afc39a1becb97946eecf737cce0d6e1b11e5dea87aaa1f61c";

        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumMarketplace.SellerNotOwnerOfToken.selector, offer.tokenId, offer.seller)
        );
        fantiumMarketplace.executeOffer(offer, signature);
    }

    function test_executeOffer_revert_TreasuryNotSet() public {
        // test setup
        // set fantiumNFT contract
        vm.startPrank(fantiumMarketplace_admin);
        fantiumMarketplace.setFANtiumNFTContract(fantiumNFT);
        assertEq(address(fantiumMarketplace.nftContract()), address(fantiumNFT));
        vm.stopPrank();

        // we do NOT set treasury
        assertEq(address(fantiumMarketplace.treasury()), address(0));

        // mint token to seller address
        address seller = 0xAAAAb8A44732De44021aac698944Ec1D47cF9031;
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;
        prepareSale(collectionId, quantity, seller);
        vm.prank(seller);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, seller); // 1000000

        // mock offer
        Offer memory offer = Offer({
            seller: seller,
            tokenAddress: address(fantiumNFT), // 0xc7183455a4C133Ae270771860664b6B7ec320bB1
            tokenId: lastTokenId,
            amount: 5,
            fee: 1,
            expiresAt: 1_704_067_300
        });

        // this signature is generated by the script from lab based on the above Offer
        bytes memory signature =
            hex"83fd858c6b36aece4c8e7fc86f6c2c4cdeae2ad271b07a40422a3bf18ea1a4be7ac86c9c243bf89259caaee39ef691fe8fb7c5487ff54aa13f79a0775231be031c";

        // try to execute offer
        vm.expectRevert(abi.encodeWithSelector(IFANtiumMarketplace.TreasuryNotSet.selector));
        fantiumMarketplace.executeOffer(offer, signature);
    }
}
