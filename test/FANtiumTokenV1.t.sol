// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../src/interfaces/IFANtiumToken.sol";
import "./setup/FANtiumTokenFactory.sol";
import { BaseTest } from "test/BaseTest.sol";
import { IFANtiumToken } from "src/interfaces/IFANtiumToken.sol";

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
    function test_setTreasuryAddress_ok() public {
        address newTreasury = makeAddr('newTreasury');
        vm.prank(fantiumToken_admin);
        vm.expectEmit(true, true, true, true);
        emit TreasuryAddressUpdate(newTreasury);
        fantiumToken.setTreasuryAddress(newTreasury);
        assertEq(fantiumToken.treasury(), newTreasury);
    }

    function test_setTreasuryAddress_revert_invalidAddress() public {
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidTreasuryAddress.selector, address(0)));
        fantiumToken.setTreasuryAddress(address(0));
    }

    function test_setTreasuryAddress_revert_sameTreasuryAddress() public {
        address newTreasury = makeAddr('newTreasury');
        vm.prank(fantiumToken_admin);
        fantiumToken.setTreasuryAddress(newTreasury);
        assertEq(fantiumToken.treasury(), newTreasury);
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.TreasuryAddressAlreadySet.selector, newTreasury));
        fantiumToken.setTreasuryAddress(newTreasury);
    }

    function test_setTreasuryAddress_revert_nonOwner() public {
        address newTreasury = makeAddr('newTreasury');
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.setTreasuryAddress(newTreasury);
    }

    // setPaymentToken
    // ========================================================================
    function test_setPaymentToken_ok() public {
        address usdcAddress = address(new MockERC20());
        vm.prank(fantiumToken_admin);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));
    }

    function test_setPaymentToken_revert_InvalidPaymentTokenAddress() public {
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidPaymentTokenAddress.selector, address(0)));
        fantiumToken.setPaymentToken(address(0), true);
    }

    function test_setPaymentToken_revert_nonOwner() public {
        address usdcAddress = address(new MockERC20());
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.setPaymentToken(usdcAddress, true);
    }
    // todo: test that you can disable previously added payment token

    // addPhase
    // ========================================================================
    function test_addPhase_ok() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);
        Phase memory addedPhase = fantiumToken.getAllPhases()[0];
        assertEq(addedPhase.pricePerShare, mockPricePerShare);
        assertEq(addedPhase.maxSupply, mockMaxSupply);
        assertEq(addedPhase.startTime, mockStartTime);
        assertEq(addedPhase.endTime, mockEndTime);
        assertEq(addedPhase.currentSupply, 0); // initially set to 0
        assertEq(addedPhase.phaseId, 0); // initially set to 0
    }

    function test_addPhase_revert_IncorrectStartOrEndTime() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 2 days);
        uint256 mockEndTime = uint256(block.timestamp + 1 days); // incorrect: start time after end time

        vm.prank(fantiumToken_admin);
        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumToken.IncorrectStartOrEndTime.selector, mockStartTime, mockEndTime)
        );
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
    }

    function test_addPhase_revert_IncorrectSharePrice() public {
        // Setup test data
        uint256 mockPricePerShare = 0; // incorrect
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days);
        uint256 mockEndTime = uint256(block.timestamp + 30 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectSharePrice.selector, mockPricePerShare));
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
    }

    function test_addPhase_revert_IncorrectMaxSupply() public {
        // Setup test data
        uint256 mockPricePerShare = 10;
        uint256 mockMaxSupply = 0; // incorrect
        uint256 mockStartTime = uint256(block.timestamp + 1 days);
        uint256 mockEndTime = uint256(block.timestamp + 30 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectMaxSupply.selector, mockMaxSupply));
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
    }

    function test_addPhase_revert_PreviousAndNextPhaseTimesOverlap() public {
        // Setup test data for Phase 1
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase was added
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // Setup test data for Phase 2
        uint256 mockStartTime2 = uint256(block.timestamp + 29 days); // incorrect - overlaps with Phase 1
        uint256 mockEndTime2 = uint256(block.timestamp + 60 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PreviousAndNextPhaseTimesOverlap.selector));

        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime2, mockEndTime2);
    }

    function test_addPhase_revert_nonOwner() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
    }

    // removePhase
    // ========================================================================
    function test_removePhase_ok_singlePhase() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // remove phase
        vm.prank(fantiumToken_admin);
        fantiumToken.removePhase(0);

        // Verify phase was removed
        assertTrue(fantiumToken.getAllPhases().length == 0);
    }

    function test_removePhase_ok_multiplePhases() public {
        // Setup test data Phase 1
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase 1 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);

        // Setup test data Phase 2
        uint256 mockPricePerShare2 = 200;
        uint256 mockMaxSupply2 = 2000;
        uint256 mockStartTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 mockEndTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Execute phase 2 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare2, mockMaxSupply2, mockStartTime2, mockEndTime2);

        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 2);

        // remove the phase 1
        vm.prank(fantiumToken_admin);
        fantiumToken.removePhase(0);

        // Verify phase was removed
        assertTrue(fantiumToken.getAllPhases().length == 1);
        // Verify the phase 1 was removed and Phase 2 is preserved
        assertEq(fantiumToken.getAllPhases()[0].pricePerShare, mockPricePerShare2);
    }

    function test_removePhase_revert_IncorrectPhaseIndex() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // remove phase
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectPhaseIndex.selector, 2));
        fantiumToken.removePhase(2); // incorrect index
    }

    function test_removePhase_revert_CannotRemovePhaseWhichAlreadyStarted() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days);
        uint256 mockEndTime = uint256(block.timestamp + 30 days);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // Warp time to after the phase has started
        vm.warp(mockStartTime + 10 days); // phase has started

        // remove phase
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CannotRemovePhaseWhichAlreadyStarted.selector));
        fantiumToken.removePhase(0);
    }

    function test_removePhase_revert_nonOwner() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days);
        uint256 mockEndTime = uint256(block.timestamp + 30 days);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // remove phase
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.removePhase(0);
    }
}
