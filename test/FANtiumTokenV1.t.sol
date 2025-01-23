// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./setup/FANtiumTokenFactory.sol";
import {BaseTest} from "test/BaseTest.sol";
import {IFANtiumToken} from 'src/interfaces/IFANtiumToken.sol';

contract FANtiumTokenV1Test is BaseTest, FANtiumTokenFactory {
    // setTreasuryAddress
    // ========================================================================
    function test_setTreasuryAddress_invalidAddress() public {
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidTreasuryAddress.selector, address(0)));
        fantiumToken.setTreasuryAddress(address(0));
    }
}
