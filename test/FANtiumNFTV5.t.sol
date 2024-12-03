// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { FANtiumNFTV5 } from "src/FANtiumNFTV5.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "test/BaseTest.sol";
import { IFANtiumNFT, Collection, CreateCollection } from "src/interfaces/IFANtiumNFT.sol";
import { FANtiumNFTFactory } from "test/setup/FANtiumNFTFactory.sol";

contract FANtiumNFTV5Test is BaseTest, FANtiumNFTFactory {
    using ECDSA for bytes32;

    address recipient = makeAddr("recipient");

    function setUp() public override {
        FANtiumNFTFactory.setUp();
    }

    // version
    // ========================================================================
    function test_version() public view {
        assertEq(fantiumNFT.version(), "5.0.0");
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
    function test_setClaimContract_ok_manager() public {
        address newClaimContract = makeAddr("newClaimContract");

        vm.prank(fantiumNFT_manager);
        fantiumNFT.setClaimContract(newClaimContract);
        assertEq(fantiumNFT.claimContract(), newClaimContract);
    }

    function test_setClaimContract_ok_admin() public {
        address newClaimContract = makeAddr("newClaimContract");

        vm.prank(fantiumNFT_admin);
        fantiumNFT.setClaimContract(newClaimContract);
        assertEq(fantiumNFT.claimContract(), newClaimContract);
    }

    function test_setClaimContract_unauthorized() public {
        address nobody = makeAddr("nobody");
        address newClaimContract = makeAddr("newClaimContract");

        expectMissingRole(nobody, fantiumNFT.MANAGER_ROLE());
        vm.prank(nobody);
        fantiumNFT.setClaimContract(newClaimContract);
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

    // mintable
    // ========================================================================
    function test_mintable_ok() public {
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

    function test_mintable_invalidCollectionId() public {
        uint256 collectionId = 999_999; // collection 999_999 does not exist
        uint24 quantity = 1;
        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.InvalidCollectionId.selector, collectionId));
        fantiumNFT.mintable(collectionId, quantity, recipient);
    }

    function test_mintable_paused() public {
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

    function test_mintable_notKyc() public {
        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        vm.startPrank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.AccountNotKYCed.selector, recipient));
        fantiumNFT.mintable(collectionId, quantity, recipient);
        vm.stopPrank();
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

        vm.expectRevert(abi.encodeWithSelector(IFANtiumNFT.InvalidSignature.selector));
        vm.prank(recipient);
        fantiumNFT.mintTo(collectionId, quantity, recipient, amountUSDC, forgedSignature);
    }

    // safeTransferFrom
    // ========================================================================
    function test_safeTransferFrom_ok() public {
        uint256 collectionId = 1;
        uint24 quantity = 1;
        uint256 lastTokenId = mintTo(collectionId, quantity, recipient);
        address recipient2 = makeAddr("recipient2");

        vm.prank(recipient);
        fantiumNFT.safeTransferFrom(recipient, recipient2, lastTokenId);
        assertEq(fantiumNFT.ownerOf(lastTokenId), recipient2);
    }

    // transferFrom
    // ========================================================================
    function test_transferFrom_ok() public {
        uint256 collectionId = 1;
        uint24 quantity = 1;
        uint256 lastTokenId = mintTo(collectionId, quantity, recipient);
        address recipient2 = makeAddr("recipient2");

        vm.prank(recipient);
        fantiumNFT.transferFrom(recipient, recipient2, lastTokenId);
        assertEq(fantiumNFT.ownerOf(lastTokenId), recipient2);
    }

    // approve
    // ========================================================================
    function test_approve_ok() public {
        address user = makeAddr("user");
        address operator = makeAddr("operator");
        uint256 collectionId = 1;
        uint24 quantity = 1;

        uint256 lastTokenId = mintTo(collectionId, quantity, user);

        vm.prank(user);
        fantiumNFT.approve(operator, lastTokenId);
        assertTrue(fantiumNFT.getApproved(lastTokenId) == operator);
    }

    // setApprovalForAll
    // ========================================================================
    function test_setApprovalForAll_ok() public {
        address user = makeAddr("user");
        address operator = makeAddr("operator");

        vm.prank(user);
        fantiumNFT.setApprovalForAll(operator, true);
        assertTrue(fantiumNFT.isApprovedForAll(user, operator));
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
}
