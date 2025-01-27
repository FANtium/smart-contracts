// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./setup/FANtiumTokenFactory.sol";
import { BaseTest } from "test/BaseTest.sol";
import { IFANtiumToken } from "src/interfaces/IFANtiumToken.sol";

contract MockContract { }

contract MockERC20 {
    function totalSupply() public returns (uint256) {
        return 10 ** 10;
    }

    function balanceOf(address wallet) public returns (uint256) {
        return 0;
    }

    function allowance(address owner, address spender) public returns (uint256) {
        return 0;
    }
}

contract FANtiumTokenV1Test is BaseTest, FANtiumTokenFactory {
    // setTreasuryAddress
    // ========================================================================
    function test_setTreasuryAddress_OK() public {
        address newTreasury = address(new MockContract());
        vm.prank(fantiumToken_admin);
        vm.expectEmit(true, true, true, true);
        emit TreasuryAddressUpdate(newTreasury);
        fantiumToken.setTreasuryAddress(newTreasury);
        assertEq(fantiumToken.treasury(), newTreasury);
    }

    function test_setTreasuryAddress_invalidAddress() public {
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidTreasuryAddress.selector, address(0)));
        fantiumToken.setTreasuryAddress(address(0));
    }

    function test_setTreasuryAddress_sameTreasuryAddress() public {
        address newTreasury = address(new MockContract());
        vm.prank(fantiumToken_admin);
        fantiumToken.setTreasuryAddress(newTreasury);
        assertEq(fantiumToken.treasury(), newTreasury);
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.TreasuryAddressAlreadySet.selector, newTreasury));
        fantiumToken.setTreasuryAddress(newTreasury);
    }

    // addPaymentToken
    // ========================================================================
    function test_addPaymentToken_OK() public {
        address usdcAddress = address(new MockERC20());
        vm.prank(fantiumToken_admin);
        fantiumToken.addPaymentToken(usdcAddress);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));
    }

    function test_addPaymentToken_InvalidPaymentTokenAddress_ZeroAddress() public {
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidPaymentTokenAddress.selector, address(0)));
        fantiumToken.addPaymentToken(address(0));
    }

    function test_addPaymentToken_InvalidPaymentTokenAddress_NonERC20() public {
        address invalidAddress = address(new MockContract()); // this contract has no totalSupply fn
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidPaymentTokenAddress.selector, invalidAddress));
        fantiumToken.addPaymentToken(invalidAddress);
    }

    // isValidPaymentToken
    // ========================================================================
    function test_isValidPaymentToken_true() public {
        address usdcAddress = address(new MockERC20());
        assertTrue(fantiumToken.isValidPaymentToken(usdcAddress));
    }

    function test_isValidPaymentToken_false() public {
        address usdcAddress = address(new MockContract());
        assertFalse(fantiumToken.isValidPaymentToken(usdcAddress));
    }
}
