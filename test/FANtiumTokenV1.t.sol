// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./setup/FANtiumTokenFactory.sol";
import { BaseTest } from "test/BaseTest.sol";
import { IFANtiumToken } from "src/interfaces/IFANtiumToken.sol";

contract MockContract {}

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

    function test_setTreasuryAddress_invalidAddressNotContract() public {
        address newTreasury = makeAddr("randomAddress");
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidTreasuryAddress.selector, newTreasury));
        fantiumToken.setTreasuryAddress(newTreasury);
    }
}
