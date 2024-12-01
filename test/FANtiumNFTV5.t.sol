// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {BaseTest} from "./BaseTest.sol";
import {FANtiumNFTV5} from "../src/FANtiumNFTV5.sol";
import {IFANtiumNFT} from "../src/interfaces/IFANtiumNFT.sol";
import {UnsafeUpgrades} from "../src/upgrades/UnsafeUpgrades.sol";
import {FANtiumNFTFactory} from "./setup/FANtiumNFTFactory.sol";

contract FANtiumNFTV5Test is BaseTest, FANtiumNFTFactory {
    function setUp() public override {
        super.setUp();
    }

    function testName() public view {
        assertEq(fantiumNFT.name(), "FANtium");
    }

    function testSymbol() public view {
        assertEq(fantiumNFT.symbol(), "FAN");
    }

    // setClaimContract
    // ========================================================================
    function test_setClaimContract_ok(address claimContract) public {
        vm.startPrank(fantiumNFT_platformManager);
        fantiumNFT.setClaimContract(claimContract);
        vm.stopPrank();
        assertEq(fantiumNFT.claimContract(), claimContract);
    }

    function test_setClaimContract_unauthorized(address claimContract) public {
        vm.startPrank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(FANtiumNFTV5.RoleNotGranted.selector, admin, fantiumNFT.PLATFORM_MANAGER_ROLE())
        );
        fantiumNFT.setClaimContract(claimContract);
        vm.stopPrank();
    }

    // setUserManager
    // ========================================================================
    function test_setUserManager_ok(address userManager) public {
        vm.startPrank(fantiumNFT_platformManager);
        fantiumNFT.setUserManager(userManager);
        vm.stopPrank();
        assertEq(fantiumNFT.fantiumUserManager(), userManager);
    }

    // mintable
    // ========================================================================
    // function test_mintable_ok(address user) public {
    //     uint256 collectionId = 1;
    //     uint24 quantity = 1;
    //     address recipient = user;

    //     deal(address(usdc), user, fantiumNFT.collections(collectionId).price * quantity);

    //     vm.startPrank(user);
    //     fantiumNFT.mintable(collectionId, quantity, recipient);
    //     vm.stopPrank();
    // }
}
