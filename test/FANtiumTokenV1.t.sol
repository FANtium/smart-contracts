// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { IFANtiumToken, Package, Phase } from "src/interfaces/IFANtiumToken.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumTokenFactory } from "test/setup/FANtiumTokenFactory.sol";

contract FANtiumTokenV1Test is BaseTest, FANtiumTokenFactory {
    // initialize
    // ========================================================================
    // TODO: test_initialize_ok
    // TODO: test_initialize_revert_alreadyInitialized

    // pause
    // ========================================================================
    function test_pause_ok_admin() public {
        vm.prank(fantiumToken_admin);
        fantiumToken.pause();
        assertTrue(fantiumToken.paused());
    }

    function test_pause_revert_unauthorized() public {
        address unauthorized = makeAddr("unauthorized");

        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        vm.prank(unauthorized);
        fantiumToken.pause();
    }

    // unpause
    // ========================================================================
    function test_unpause_ok_admin() public {
        // First pause the contract
        vm.prank(fantiumToken_admin);
        fantiumToken.pause();
        assertTrue(fantiumToken.paused());

        // Then unpause it
        vm.prank(fantiumToken_admin);
        fantiumToken.unpause();
        assertFalse(fantiumToken.paused());
    }

    function test_unpause_revert_unauthorized() public {
        // First pause the contract
        vm.prank(fantiumToken_admin);
        fantiumToken.pause();
        assertTrue(fantiumToken.paused());

        address unauthorized = makeAddr("unauthorized");

        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        vm.prank(unauthorized);
        fantiumToken.unpause();
    }

    // isTrustedForwarder
    // ========================================================================
    // TODO: test_isTrustedForwarder_ok_withRole
    // TODO: test_isTrustedForwarder_ok_withoutRole

    // _msgSender
    // ========================================================================
    // TODO: test_msgSender_ok_regularCall
    // TODO: test_msgSender_ok_trustedForwarder

    // _msgData
    // ========================================================================
    // TODO: test_msgData_ok_regularCall
    // TODO: test_msgData_ok_trustedForwarder

    // setTreasuryAddress
    // ========================================================================
    function test_setTreasuryAddress_ok() public {
        address newTreasury = makeAddr("newTreasury");
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
        address newTreasury = makeAddr("newTreasury");
        vm.prank(fantiumToken_admin);
        fantiumToken.setTreasuryAddress(newTreasury);
        assertEq(fantiumToken.treasury(), newTreasury);
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.TreasuryAddressAlreadySet.selector, newTreasury));
        fantiumToken.setTreasuryAddress(newTreasury);
    }

    function test_setTreasuryAddress_revert_nonOwner() public {
        address newTreasury = makeAddr("newTreasury");
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumToken.setTreasuryAddress(newTreasury);
    }

    // setPaymentToken
    // ========================================================================
    function test_setPaymentToken_ok() public {
        address usdcAddress = address(usdc);
        vm.prank(fantiumToken_admin);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));
    }

    function test_setPaymentToken_ok_disableToken() public {
        // we need to add some token first
        address usdcAddress = address(usdc);
        vm.prank(fantiumToken_admin);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // test that you can disable previously added payment token
        vm.prank(fantiumToken_admin);
        fantiumToken.setPaymentToken(usdcAddress, false);
        assertFalse(fantiumToken.erc20PaymentTokens(usdcAddress));
    }

    function test_setPaymentToken_revert_InvalidPaymentTokenAddress() public {
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidPaymentTokenAddress.selector, address(0)));
        fantiumToken.setPaymentToken(address(0), true);
    }

    function test_setPaymentToken_revert_nonOwner() public {
        address usdcAddress = address(usdc);
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumToken.setPaymentToken(usdcAddress, true);
    }

    // addPhase
    // ========================================================================
    function test_addPhase_ok() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);
        Phase memory addedPhase = fantiumToken.getAllPhases()[0];
        assertEq(addedPhase.pricePerShare, pricePerShare);
        assertEq(addedPhase.maxSupply, maxSupply);
        assertEq(addedPhase.startTime, startTime);
        assertEq(addedPhase.endTime, endTime);
        assertEq(addedPhase.currentSupply, 0); // initially set to 0
        assertEq(addedPhase.phaseId, 0); // initially set to 0
    }

    function test_addPhase_ok_multiplePhases() public {
        // Setup test data for 1st phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Setup test data for 2nd phase
        uint256 pricePerShare2 = 200;
        uint256 maxSupply2 = 2000;
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase 1 addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Execute phase 2 addition
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);

        vm.stopPrank();

        // verify both phases was added
        assertEq(fantiumToken.getAllPhases().length, 2);

        // Verify phase 1 data was stored correctly
        Phase memory addedPhase = fantiumToken.getAllPhases()[0];
        assertEq(addedPhase.pricePerShare, pricePerShare);
        assertEq(addedPhase.maxSupply, maxSupply);
        assertEq(addedPhase.startTime, startTime);
        assertEq(addedPhase.endTime, endTime);
        assertEq(addedPhase.currentSupply, 0); // initially set to 0
        assertEq(addedPhase.phaseId, 0);

        // Verify phase 2 data was stored correctly
        Phase memory addedPhase2 = fantiumToken.getAllPhases()[1];
        assertEq(addedPhase2.pricePerShare, pricePerShare2);
        assertEq(addedPhase2.maxSupply, maxSupply2);
        assertEq(addedPhase2.startTime, startTime2);
        assertEq(addedPhase2.endTime, endTime2);
        assertEq(addedPhase2.currentSupply, 0); // initially set to 0
        assertEq(addedPhase2.phaseId, 1);
    }

    function test_addPhase_revert_IncorrectStartOrEndTime() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days);
        uint256 endTime = uint256(block.timestamp + 1 days); // incorrect: start time after end time

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectStartOrEndTime.selector, startTime, endTime));
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
    }

    function test_addPhase_revert_IncorrectSharePrice() public {
        // Setup test data
        uint256 pricePerShare = 0; // incorrect
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectSharePrice.selector, pricePerShare));
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
    }

    function test_addPhase_revert_IncorrectMaxSupply() public {
        // Setup test data
        uint256 pricePerShare = 10;
        uint256 maxSupply = 0; // incorrect
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectMaxSupply.selector, maxSupply));
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
    }

    function test_addPhase_revert_PreviousAndNextPhaseTimesOverlap() public {
        // Setup test data for Phase 1
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Setup test data for Phase 2
        uint256 startTime2 = uint256(block.timestamp + 29 days); // incorrect - overlaps with Phase 1
        uint256 endTime2 = uint256(block.timestamp + 60 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PreviousAndNextPhaseTimesOverlap.selector));

        fantiumToken.addPhase(pricePerShare, maxSupply, startTime2, endTime2);
    }

    function test_addPhase_revert_nonOwner() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
    }

    // removePhase
    // ========================================================================
    function test_removePhase_ok_singlePhase() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // remove phase
        vm.prank(fantiumToken_admin);
        fantiumToken.removePhase(0);

        // Verify phase was removed
        assertEq(fantiumToken.getAllPhases().length, 0);
    }

    function test_removePhase_ok_multiplePhases() public {
        // Setup test data Phase 1
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase 1 addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);

        // Setup test data Phase 2
        uint256 pricePerShare2 = 200;
        uint256 maxSupply2 = 2000;
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Execute phase 2 addition
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);

        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        // remove the phase 1
        fantiumToken.removePhase(0);

        // Verify phase was removed
        assertEq(fantiumToken.getAllPhases().length, 1);
        // Verify the phase 1 was removed and Phase 2 is preserved
        assertEq(fantiumToken.getAllPhases()[0].pricePerShare, pricePerShare2);

        vm.stopPrank();
    }

    function test_removePhase_revert_IncorrectPhaseIndex() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // remove phase
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectPhaseIndex.selector, 2));
        fantiumToken.removePhase(2); // incorrect index
    }

    function test_removePhase_revert_CannotRemovePhaseWhichAlreadyStarted() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time to after the phase has started
        vm.warp(startTime + 10 days); // phase has started

        // remove phase
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CannotRemovePhaseWhichAlreadyStarted.selector));
        fantiumToken.removePhase(0);
    }

    function test_removePhase_revert_nonOwner() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // remove phase
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumToken.removePhase(0);
    }

    // setCurrentPhase
    // ========================================================================
    function test_setCurrentPhase_ok() public {
        // add phases
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase 1 addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Execute phase 2 addition
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime2, endTime2);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        // try to set phase 1 as current phase
        fantiumToken.setCurrentPhase(0);
        vm.assertEq(fantiumToken.getCurrentPhase().phaseId, 0);

        // try to set phase 2 as current phase
        fantiumToken.setCurrentPhase(1);
        vm.assertEq(fantiumToken.getCurrentPhase().phaseId, 1);

        vm.stopPrank();
    }

    function test_setCurrentPhase_revert_IncorrectPhaseIndex() public {
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectPhaseIndex.selector, 2));
        fantiumToken.setCurrentPhase(2);
    }

    function test_setCurrentPhase_revert_CannotSetEndedPhaseAsCurrentPhase() public {
        // add phases
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase 1 addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Execute phase 2 addition
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime2, endTime2);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        // Warp time to after the phase has started
        vm.warp(startTime + 50 days); // phase 1 has ended

        // try to set ended phase 1 as current phase
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CannotSetEndedPhaseAsCurrentPhase.selector));
        fantiumToken.setCurrentPhase(0);

        vm.stopPrank();
    }

    function test_setCurrentPhase_revert_nonOwner() public {
        // add phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // try to set phase as current phase
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumToken.setCurrentPhase(0);
    }

    // getCurrentPhase
    // ========================================================================
    function test_getCurrentPhase_ok() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // set phase as current
        vm.prank(fantiumToken_admin);
        fantiumToken.setCurrentPhase(0);

        // check that getCurrentPhase returns correct phase data
        vm.assertEq(fantiumToken.getCurrentPhase().phaseId, 0);
        vm.assertEq(fantiumToken.getCurrentPhase().pricePerShare, pricePerShare);
        vm.assertEq(fantiumToken.getCurrentPhase().maxSupply, maxSupply);
        vm.assertEq(fantiumToken.getCurrentPhase().startTime, startTime);
        vm.assertEq(fantiumToken.getCurrentPhase().endTime, endTime);
    }

    // test_getCurrentPhase_PhaseDoesNotExist - there is no way to test this atm, because the setCurrentPhase will not
    // allow us to set non existing phase

    function test_getCurrentPhase_revert_NoPhasesAdded() public {
        // Check the initial state - no phases added
        assertEq(fantiumToken.getAllPhases().length, 0);

        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.NoPhasesAdded.selector));
        fantiumToken.getCurrentPhase();
    }

    // getAllPhases
    // ========================================================================
    function test_getAllPhases_ok_empty() public view {
        // Check that getAllPhases returns an empty array when no phases are added
        Phase[] memory phases = fantiumToken.getAllPhases();

        // Verify the array is empty
        assertEq(phases.length, 0);
    }

    function test_getAllPhases_ok() public {
        // add 2 phases
        uint256 pricePerShare = 100;
        uint256 pricePerShare2 = 200;
        uint256 maxSupply = 1000;
        uint256 maxSupply2 = 2000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase 1 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Execute phase 2 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        // check that getAllPhases returns correct data
        fantiumToken.getAllPhases();
        Phase[] memory allPhases = fantiumToken.getAllPhases();
        vm.assertEq(allPhases[0].phaseId, 0);
        vm.assertEq(allPhases[0].pricePerShare, pricePerShare);
        vm.assertEq(allPhases[0].maxSupply, maxSupply);
        vm.assertEq(allPhases[0].startTime, startTime);
        vm.assertEq(allPhases[1].phaseId, 1);
        vm.assertEq(allPhases[1].pricePerShare, pricePerShare2);
        vm.assertEq(allPhases[1].maxSupply, maxSupply2);
        vm.assertEq(allPhases[1].startTime, startTime2);
    }

    // changePhaseStartTime
    // ========================================================================
    function test_changePhaseStartTime_ok() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);
        assertEq(fantiumToken.getAllPhases()[0].endTime, endTime);

        uint256 mockNewStartTime = uint256(block.timestamp + 3 days);
        // change start time
        vm.prank(fantiumToken_admin);
        fantiumToken.changePhaseStartTime(mockNewStartTime, 0);
        // check that it has been changed
        vm.assertEq(fantiumToken.getAllPhases()[0].startTime, mockNewStartTime);
    }

    function test_changePhaseStartTime_revert_PhaseNotFound() public {
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PhaseNotFound.selector, 1));
        fantiumToken.changePhaseEndTime(endTime, 1);
    }

    function test_changePhaseStartTime_revert_IncorrectStartTime() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 mockNewStartTime = uint256(block.timestamp + 31 days); // incorrect - after the end time

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectStartTime.selector, mockNewStartTime));
        fantiumToken.changePhaseStartTime(mockNewStartTime, 0);
    }

    function test_changePhaseStartTime_revert_PreviousAndNextPhaseTimesOverlap() public {
        // add 2 phases
        uint256 pricePerShare = 100;
        uint256 pricePerShare2 = 200;
        uint256 maxSupply = 1000;
        uint256 maxSupply2 = 2000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase 1 addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Execute phase 2 addition
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        uint256 mockNewStartTime = uint256(block.timestamp + 29 days); // incorrect - overlaps with phase 1

        // try to set new start time for phase 2, which overlaps with phase 1
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PreviousAndNextPhaseTimesOverlap.selector));
        fantiumToken.changePhaseStartTime(mockNewStartTime, 1);

        vm.stopPrank();
    }

    function test_changePhaseStartTime_revert_nonOwner() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 mockNewStartTime = uint256(block.timestamp + 3 days);

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumToken.changePhaseStartTime(mockNewStartTime, 0);
    }

    // changePhaseEndTime
    // ========================================================================
    function test_changePhaseEndTime_ok() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);
        assertEq(fantiumToken.getAllPhases()[0].endTime, endTime);

        uint256 mockNewEndTime = uint256(block.timestamp + 40 days);
        // change end time
        vm.prank(fantiumToken_admin);
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);
        // check that it has been changed
        vm.assertEq(fantiumToken.getAllPhases()[0].endTime, mockNewEndTime);
    }

    function test_changePhaseEndTime_revert_PhaseNotFound() public {
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PhaseNotFound.selector, 1));
        fantiumToken.changePhaseEndTime(endTime, 1);
    }

    function test_changePhaseEndTime_revert_IncorrectEndTime() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 mockNewEndTime = uint256(block.timestamp + 1 days); // incorrect - before the start time

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectEndTime.selector, mockNewEndTime));
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);
    }

    function test_changePhaseEndTime_revert_PreviousAndNextPhaseTimesOverlap() public {
        // add 2 phases
        uint256 pricePerShare = 100;
        uint256 pricePerShare2 = 200;
        uint256 maxSupply = 1000;
        uint256 maxSupply2 = 2000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase 1 addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Execute phase 2 addition
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        uint256 mockNewEndTime = uint256(block.timestamp + 32 days); // incorrect - overlaps with phase 2

        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PreviousAndNextPhaseTimesOverlap.selector));
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);

        vm.stopPrank();
    }

    function test_changePhaseEndTime_revert_nonOwner() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 mockNewEndTime = uint256(block.timestamp + 31 days);

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);
    }

    // changePhaseMaxSupply
    // ========================================================================
    function test_changePhaseMaxSupply_ok() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 newmaxSupply = 5000;

        // change max supply
        vm.prank(fantiumToken_admin);
        fantiumToken.changePhaseMaxSupply(newmaxSupply, 0);
        vm.assertEq(fantiumToken.getAllPhases()[0].maxSupply, newmaxSupply);
    }

    function test_changePhaseMaxSupply_revert_PhaseNotFound() public {
        uint256 maxSupply = 1000;

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PhaseNotFound.selector, 1));
        fantiumToken.changePhaseMaxSupply(maxSupply, 1);
    }

    function test_changePhaseMaxSupply_revert_InvalidMaxSupplyValue() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidMaxSupplyValue.selector, 0));
        fantiumToken.changePhaseMaxSupply(0, 0); // passing maxSupply 0
    }

    function test_changePhaseMaxSupply_revert_CannotUpdateEndedSalePhase() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time to after the phase has started
        vm.warp(endTime + 1 days); // phase has ended

        uint256 newmaxSupply = 5000;

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CannotUpdateEndedSalePhase.selector));
        fantiumToken.changePhaseMaxSupply(newmaxSupply, 0); // passing maxSupply 0
    }

    function test_changePhaseMaxSupply_revert_nonOwner() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 newmaxSupply = 5000;

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumToken.changePhaseMaxSupply(newmaxSupply, 0);
    }

    // mintTo (single share(s))
    // ========================================================================
    function test_mintTo_ok() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        vm.stopPrank();

        // prepare sale
        address recipient = makeAddr("recipient");
        uint256 quantity = 20;
        uint8 tokenDecimals = IERC20MetadataUpgradeable(usdcAddress).decimals();
        uint256 expectedAmount = quantity * pricePerShare * 10 ** tokenDecimals;
        // top up recipient
        deal(usdcAddress, recipient, expectedAmount);
        vm.startPrank(recipient);
        // approve the spending
        usdc.approve(address(fantiumToken), expectedAmount);

        // mint
        vm.expectEmit(true, true, true, true); // check that event was emitted
        emit FANtiumTokenSale(quantity, recipient, expectedAmount, usdcAddress);
        fantiumToken.mintTo(recipient, quantity, usdcAddress);

        // check that currentSupply has increased
        assertEq(fantiumToken.getCurrentPhase().currentSupply, quantity);

        vm.stopPrank();
    }

    function test_mintTo_ok_autoPhaseSwitch() public {
        // add 2 phases
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        uint256 pricePerShare2 = 200;
        uint256 maxSupply2 = 2000;
        uint256 startTime2 = uint256(block.timestamp + 31 days);
        uint256 endTime2 = uint256(block.timestamp + 60 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phases addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);
        // Verify phases were added
        assertEq(fantiumToken.getAllPhases().length, 2);

        // Warp time
        vm.warp(startTime + 1 days); // phase 1 is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        // check current phase
        Phase memory currentPhase = fantiumToken.getCurrentPhase();
        assertEq(currentPhase.phaseId, 0);

        vm.stopPrank();

        // prepare sale
        address recipient = makeAddr("recipient");
        uint256 quantity = maxSupply; // buy all shares in phase1
        uint8 tokenDecimals = IERC20MetadataUpgradeable(usdcAddress).decimals();
        uint256 expectedAmount = quantity * pricePerShare * 10 ** tokenDecimals;
        // top up recipient
        deal(usdcAddress, recipient, expectedAmount);
        vm.startPrank(recipient);
        // approve the spending
        usdc.approve(address(fantiumToken), expectedAmount);

        // mint
        vm.expectEmit(true, true, true, true); // check that event was emitted
        emit FANtiumTokenSale(quantity, recipient, expectedAmount, usdcAddress);
        fantiumToken.mintTo(recipient, quantity, usdcAddress);

        // check that current phase switch worked
        Phase memory updatedCurrentPhase = fantiumToken.getCurrentPhase();
        assertEq(updatedCurrentPhase.phaseId, 1);

        vm.stopPrank();
    }

    function test_mintTo_revert_CurrentPhaseIsNotActive_phaseNotStarted() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // phase will start in 2 days!
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // try to mint
        address recipient = makeAddr("recipient");
        address usdcAddress = address(usdc);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CurrentPhaseIsNotActive.selector));
        fantiumToken.mintTo(recipient, 10, usdcAddress);
    }

    function test_mintTo_revert_IncorrectTokenQuantity() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // try to mint
        address recipient = makeAddr("recipient");
        address usdcAddress = address(usdc);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectTokenQuantity.selector, 0));
        fantiumToken.mintTo(recipient, 0, usdcAddress); // passing quantity 0 !
    }

    function test_mintTo_revert_QuantityExceedsMaxSupplyLimit() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        vm.stopPrank();

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // try to mint
        address recipient = makeAddr("recipient");
        uint256 quantity = 1001; // more than maxSupply
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.QuantityExceedsMaxSupplyLimit.selector, quantity));
        fantiumToken.mintTo(recipient, quantity, usdcAddress);
    }

    function test_mintTo_revert_ERC20PaymentTokenIsNotSet() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // try to mint
        address recipient = makeAddr("recipient");
        address usdcAddress = address(usdc);
        uint256 quantity = 20;
        // we skip the step of setting the payment token
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.ERC20PaymentTokenIsNotSet.selector));
        fantiumToken.mintTo(recipient, quantity, usdcAddress);
    }

    function test_mintTo_revert_TreasuryIsNotSet() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        vm.prank(fantiumToken_admin);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // try to mint
        address recipient = makeAddr("recipient");
        uint256 quantity = 20;
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.TreasuryIsNotSet.selector));
        fantiumToken.mintTo(recipient, quantity, usdcAddress);
    }

    function test_mintTo_revert_whenPaused() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        // Pause the contract
        fantiumToken.pause();

        // Verify the contract is paused
        assertTrue(fantiumToken.paused());

        vm.stopPrank();

        // prepare sale
        address recipient = makeAddr("recipient");
        uint256 quantity = 20;
        uint8 tokenDecimals = IERC20MetadataUpgradeable(usdcAddress).decimals();
        uint256 expectedAmount = quantity * pricePerShare * 10 ** tokenDecimals;
        // top up recipient
        deal(usdcAddress, recipient, expectedAmount);
        vm.startPrank(recipient);
        // approve the spending
        usdc.approve(address(fantiumToken), expectedAmount);

        // Try to mint when paused - should revert
        vm.expectRevert("Pausable: paused");
        // try to mint
        fantiumToken.mintTo(recipient, quantity, usdcAddress);

        vm.stopPrank();

        // Unpause
        vm.prank(fantiumToken_admin);
        fantiumToken.unpause();
    }

    function test_mintTo_revert_insufficientAllowance() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        vm.stopPrank();

        // prepare sale
        address recipient = makeAddr("recipient");
        uint256 quantity = 20;
        uint8 tokenDecimals = IERC20MetadataUpgradeable(usdcAddress).decimals();
        uint256 expectedAmount = quantity * pricePerShare * 10 ** tokenDecimals;
        // top up recipient
        deal(usdcAddress, recipient, expectedAmount);
        vm.startPrank(recipient);
        // approve the spending
        usdc.approve(address(fantiumToken), expectedAmount - 10); // Approve less than needed

        // mint
        vm.expectRevert("ERC20: insufficient allowance");
        fantiumToken.mintTo(recipient, quantity, usdcAddress);

        vm.stopPrank();
    }

    function test_mintTo_revert_insufficientBalance() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        vm.stopPrank();

        // prepare sale
        address recipient = makeAddr("recipient");
        uint256 quantity = 20;
        uint8 tokenDecimals = IERC20MetadataUpgradeable(usdcAddress).decimals();
        uint256 expectedAmount = quantity * pricePerShare * 10 ** tokenDecimals;
        // top up recipient
        deal(usdcAddress, recipient, expectedAmount - 10); // Top up less than needed
        vm.startPrank(recipient);
        // approve the spending
        usdc.approve(address(fantiumToken), expectedAmount);

        // mint
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        fantiumToken.mintTo(recipient, quantity, usdcAddress);

        vm.stopPrank();
    }

    // mintTo (packages)
    // ========================================================================
    function test_mintTo_packages_ok() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        // setup package data
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 3;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        // Execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        // check that package was added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 1);

        uint256 packageId = fantiumToken.getAllPhases()[0].packages[0].packageId;

        vm.stopPrank();

        // prepare sale
        address recipient = makeAddr("recipient");
        uint256 packagesQuantity = 5;
        uint256 quantity = packagesQuantity * shareCount;
        uint8 tokenDecimals = IERC20MetadataUpgradeable(usdcAddress).decimals();
        uint256 expectedAmount = packagesQuantity * price * 10 ** tokenDecimals;
        // top up recipient
        deal(usdcAddress, recipient, expectedAmount);
        vm.startPrank(recipient);
        // approve the spending
        usdc.approve(address(fantiumToken), expectedAmount);

        // mint
        vm.expectEmit(true, true, true, true); // check that event was emitted
        emit FANtiumTokenPackageSale(recipient, packageId, packagesQuantity, quantity, usdcAddress, expectedAmount);
        fantiumToken.mintTo(recipient, packagesQuantity, usdcAddress, packageId);

        // check that token currentSupply has increased
        assertEq(fantiumToken.getCurrentPhase().currentSupply, quantity);

        // check that package currentSupply has increased
        assertEq(fantiumToken.getAllPhases()[0].packages[0].currentSupply, packagesQuantity); // should increase from 0
            // to packagesQuantity

        vm.stopPrank();
    }

    function test_mintTo_packages_ok_autoPhaseSwitch() public {
        // add 2 phases
        uint256 pricePerShare = 200;
        uint256 maxSupply = 100;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        uint256 pricePerShare2 = 200;
        uint256 maxSupply2 = 2000;
        uint256 startTime2 = uint256(block.timestamp + 31 days);
        uint256 endTime2 = uint256(block.timestamp + 60 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phases addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);
        // Verify phases were added
        assertEq(fantiumToken.getAllPhases().length, 2);

        // Warp time
        vm.warp(startTime + 1 days); // phase 1 is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        // setup package data
        string memory name = "Premium";
        uint256 price = 1000;
        uint256 shareCount = 5;
        uint256 maxPackageSupply = 20;
        uint256 phaseId = 0;

        // Execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        // check that package was added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 1);

        uint256 packageId = fantiumToken.getAllPhases()[0].packages[0].packageId;

        vm.stopPrank();

        // prepare sale
        address recipient = makeAddr("recipient");
        uint256 packagesQuantity = 20; // we purchase all packages -> all shares
        uint256 quantity = packagesQuantity * shareCount;
        uint8 tokenDecimals = IERC20MetadataUpgradeable(usdcAddress).decimals();
        uint256 expectedAmount = packagesQuantity * price * 10 ** tokenDecimals;
        // top up recipient
        deal(usdcAddress, recipient, expectedAmount);
        vm.startPrank(recipient);
        // approve the spending
        usdc.approve(address(fantiumToken), expectedAmount);

        // mint
        vm.expectEmit(true, true, true, true); // check that event was emitted
        emit FANtiumTokenPackageSale(recipient, packageId, packagesQuantity, quantity, usdcAddress, expectedAmount);
        fantiumToken.mintTo(recipient, packagesQuantity, usdcAddress, packageId);

        // check that token currentSupply has increased for 1st phase
        assertEq(fantiumToken.getAllPhases()[0].currentSupply, quantity);

        // check that package currentSupply has increased
        assertEq(fantiumToken.getAllPhases()[0].packages[0].currentSupply, packagesQuantity); // should increase from 0
            // to packagesQuantity

        // check that current phase switch worked
        Phase memory updatedCurrentPhase = fantiumToken.getCurrentPhase();
        assertEq(updatedCurrentPhase.phaseId, 1);

        vm.stopPrank();
    }

    function test_mintTo_packages_revert_CurrentPhaseIsNotActive_phaseNotStarted() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // phase will start in 2 days!
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // try to mint
        address recipient = makeAddr("recipient");
        address usdcAddress = address(usdc);
        vm.prank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CurrentPhaseIsNotActive.selector));
        fantiumToken.mintTo(recipient, 10, usdcAddress, 0);
    }

    function test_mintTo_packages_revert_IncorrectPackageQuantity() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase 1 is active

        // try to mint
        address recipient = makeAddr("recipient");
        address usdcAddress = address(usdc);
        vm.prank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectPackageQuantity.selector, 0));
        fantiumToken.mintTo(recipient, 0, usdcAddress, 0); // passing wrong package quantity
    }

    function test_mintTo_packages_revert_QuantityExceedsMaxSupplyLimit() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 999;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        // setup package data
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 100;
        uint256 maxPackageSupply = 10; // shareCount * maxPackageSupply > phase.maxSupply
        uint256 phaseId = 0;

        // Execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        // check that package was added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 1);

        vm.stopPrank();

        // try to mint
        address recipient = makeAddr("recipient");
        vm.prank(recipient);
        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumToken.QuantityExceedsMaxSupplyLimit.selector, maxPackageSupply * shareCount)
        );
        fantiumToken.mintTo(recipient, maxPackageSupply, usdcAddress, 0); // passing maxPackageSupply as packageQuantity
    }

    function test_mintTo_packages_revert_PackageQuantityExceedsMaxSupplyLimit() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        // setup package data
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 100;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        // Execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        // check that package was added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 1);

        vm.stopPrank();

        // try to mint
        address recipient = makeAddr("recipient");
        vm.prank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PackageQuantityExceedsMaxSupplyLimit.selector, 11));
        fantiumToken.mintTo(recipient, 11, usdcAddress, 0); // passing 11 as packageQuantity > maxPackageSupply
    }

    function test_mintTo_packages_revert_ERC20PaymentTokenIsNotSet() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        // setup package data
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 100;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        // Execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        // check that package was added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 1);

        vm.stopPrank();

        // try to mint
        address recipient = makeAddr("recipient");
        address usdcAddress = address(usdc);
        vm.prank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.ERC20PaymentTokenIsNotSet.selector));
        fantiumToken.mintTo(recipient, 1, usdcAddress, 0);
    }

    function test_mintTo_packages_revert_TreasuryIsNotSet() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // setup package data
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 100;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        // Execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        // check that package was added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 1);

        vm.stopPrank();

        // try to mint
        address recipient = makeAddr("recipient");
        vm.prank(recipient);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.TreasuryIsNotSet.selector));
        fantiumToken.mintTo(recipient, 1, usdcAddress, 0);
    }

    function test_mintTo_packages_revert_whenPaused() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // setup package data
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 100;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        // Execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        // check that package was added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 1);

        // Pause the contract
        fantiumToken.pause();

        vm.stopPrank();

        address recipient = makeAddr("recipient");
        vm.prank(recipient);
        // Try to mint when paused - should revert
        vm.expectRevert("Pausable: paused");
        fantiumToken.mintTo(recipient, 1, usdcAddress, 0);
    }

    // TODO: test_mintTo_packages_revert_insufficientAllowance
    // TODO: test_mintTo_packages_revert_insufficientBalance

    // addPackage
    // ========================================================================
    function test_addPackage_ok() public {
        // Setup test data for phase addition
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // setup test data for package
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 3;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        // Execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        // check that package was added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 1);

        // verify package data
        assertEq(fantiumToken.getAllPackagesForPhase(0)[0].name, name);
        assertEq(fantiumToken.getAllPackagesForPhase(0)[0].price, price);
        assertEq(fantiumToken.getAllPackagesForPhase(0)[0].shareCount, shareCount);
        assertEq(fantiumToken.getAllPackagesForPhase(0)[0].maxSupply, maxPackageSupply);
        assertEq(fantiumToken.getAllPackagesForPhase(0)[0].packageId, 0);

        // check that nextPackageId is incremented
        assertEq(fantiumToken.getAllPhases()[0].nextPackageId, 1);

        vm.stopPrank();
    }

    function test_addPackage_ok_multiple() public {
        // Setup test data for phase addition
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // setup test data for 2 packages
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 3;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        string memory name2 = "Basic";
        uint256 price2 = 666;
        uint256 shareCount2 = 2;
        uint256 maxPackageSupply2 = 20;

        // Execute packages addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);
        fantiumToken.addPackage(name2, price2, shareCount2, maxPackageSupply2, phaseId);

        // check that 2 packages were added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 2);
        // verify package data
        assertEq(fantiumToken.getAllPackagesForPhase(0)[0].packageId, 0);
        assertEq(fantiumToken.getAllPackagesForPhase(0)[1].packageId, 1);

        vm.stopPrank();
    }

    function test_addPackage_revert_IncorrectPackageName() public {
        // Setup test data for phase addition
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // setup test data for package
        string memory name = ""; // empty!
        uint256 price = 999;
        uint256 shareCount = 3;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectPackageName.selector, name));
        // try to execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        vm.stopPrank();
    }

    function test_addPackage_revert_IncorrectPackagePrice() public {
        // Setup test data for phase addition
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // setup test data for package
        string memory name = "Premium";
        uint256 price = 0; // incorrect!
        uint256 shareCount = 3;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectPackagePrice.selector, price));
        // try to execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        vm.stopPrank();
    }

    function test_addPackage_revert_IncorrectShareCount() public {
        // Setup test data for phase addition
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // setup test data for package
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 0; // incorrect!
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectShareCount.selector, shareCount));
        // try to execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        vm.stopPrank();
    }

    function test_addPackage_revert_IncorrectMaxSupply() public {
        // Setup test data for phase addition
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // setup test data for package
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 3;
        uint256 maxPackageSupply = 0; // incorrect!
        uint256 phaseId = 0;

        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectMaxSupply.selector, maxPackageSupply));
        // try to execute package addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        vm.stopPrank();
    }

    // removePackage
    // ========================================================================
    function test_removePackage_ok() public {
        // Setup test data for phase addition
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // setup test data for 2 packages
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 3;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        string memory name2 = "Basic";
        uint256 price2 = 666;
        uint256 shareCount2 = 2;
        uint256 maxPackageSupply2 = 20;

        // Execute packages addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);
        fantiumToken.addPackage(name2, price2, shareCount2, maxPackageSupply2, phaseId);

        // check that 2 packages were added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 2);

        // remove second package
        fantiumToken.removePackage(0, 1);

        // check that only 1st package remains
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 1);
        assertEq(fantiumToken.getAllPhases()[0].packages[0].name, "Premium");

        vm.stopPrank();
    }

    function test_removePackage_ok_multiple() public {
        // Setup test data for phase addition
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // setup test data for 2 packages
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 3;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        string memory name2 = "Basic";
        uint256 price2 = 666;
        uint256 shareCount2 = 2;
        uint256 maxPackageSupply2 = 20;

        // Execute packages addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);
        fantiumToken.addPackage(name2, price2, shareCount2, maxPackageSupply2, phaseId);

        // check that 2 packages were added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 2);

        // remove all packages
        fantiumToken.removePackage(0, 0);
        fantiumToken.removePackage(0, 1);

        // check that no packages left
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 0);

        vm.stopPrank();
    }

    function test_removePackage_revert_PhaseNotFound() public {
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0); // no phases added

        uint256 phaseId = 0; // there is no such phase

        vm.startPrank(fantiumToken_admin);

        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PhaseNotFound.selector, phaseId));
        // Try to remove package
        fantiumToken.removePackage(phaseId, 0);

        vm.stopPrank();
    }

    function test_removePackage_revert_PackageDoesNotExist() public {
        // Setup test data for phase addition
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // setup package data
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 3;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        vm.startPrank(fantiumToken_admin);

        // add package with id = 0
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);

        // check that package was added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 1);

        // try to remove non-existing package with id = 2
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PackageDoesNotExist.selector, 2));
        fantiumToken.removePackage(phaseId, 2); // package with id:2 doesn't exist

        vm.stopPrank();
    }

    // getAllPackagesForPhase
    // ========================================================================
    function test_getAllPackagesForPhase_ok() public {
        // Setup test data for phase addition
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // setup test data for 2 packages
        string memory name = "Premium";
        uint256 price = 999;
        uint256 shareCount = 3;
        uint256 maxPackageSupply = 10;
        uint256 phaseId = 0;

        string memory name2 = "Basic";
        uint256 price2 = 666;
        uint256 shareCount2 = 2;
        uint256 maxPackageSupply2 = 20;

        // Execute packages addition
        fantiumToken.addPackage(name, price, shareCount, maxPackageSupply, phaseId);
        fantiumToken.addPackage(name2, price2, shareCount2, maxPackageSupply2, phaseId);

        // check that 2 packages were added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 2);

        // check that getAllPackagesForPhase returns all 2 packages
        assertEq(fantiumToken.getAllPackagesForPhase(0).length, 2);
        assertEq(fantiumToken.getAllPackagesForPhase(0)[0].name, name);
        assertEq(fantiumToken.getAllPackagesForPhase(0)[1].name, name2);

        vm.stopPrank();
    }

    function test_getAllPackagesForPhase_ok_empty() public {
        // Setup test data for phase addition
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // check that NO packages were added
        assertEq(fantiumToken.getAllPhases()[0].packages.length, 0);

        // check that getAllPackagesForPhase returns 0 packages
        assertEq(fantiumToken.getAllPackagesForPhase(0).length, 0);

        vm.stopPrank();
    }

    function test_getAllPackagesForPhase_revert_PhaseNotFound() public {
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        vm.startPrank(fantiumToken_admin);

        // check that getAllPackagesForPhase reverts
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PhaseNotFound.selector, 0));
        fantiumToken.getAllPackagesForPhase(0); // no phase with id = 0

        vm.stopPrank();
    }

    // batchTransferFrom
    // ========================================================================
    // TODO: test_batchTransferFrom_ok
    // TODO: test_batchTransferFrom_revert_whenPaused
    // TODO: test_batchTransferFrom_revert_notOwnerOrApproved
    // TODO: test_batchTransferFrom_revert_toZeroAddress

    // batchSafeTransferFrom
    // ========================================================================
    // TODO: test_batchSafeTransferFrom_ok
    // TODO: test_batchSafeTransferFrom_revert_whenPaused
    // TODO: test_batchSafeTransferFrom_revert_notOwnerOrApproved
    // TODO: test_batchSafeTransferFrom_revert_toZeroAddress
}
