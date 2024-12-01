// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {FANtiumUserManagerV2} from "../src/FANtiumUserManagerV2.sol";
import {UnsafeUpgrades} from "../src/upgrades/UnsafeUpgrades.sol";

contract FANtiumUserManagerV2Test is Test {
    FANtiumUserManagerV2 public userManager;

    address public admin = makeAddr("admin");
    address public kycManager = makeAddr("kycManager");
    address public allowlistManager = makeAddr("allowlistManager");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Need to copy the events from the FANtiumUserManagerV2 contract
    event KYCUpdate(address indexed account, bool isKYCed);
    event IDENTUpdate(address indexed account, bool isIDENT);
    event AllowListUpdate(address indexed account, uint256 indexed collectionId, uint256 amount);

    function setUp() public {
        address implementation = address(new FANtiumUserManagerV2());
        address proxy =
            UnsafeUpgrades.deployUUPSProxy(implementation, abi.encodeCall(FANtiumUserManagerV2.initialize, (admin)));
        userManager = FANtiumUserManagerV2(proxy);

        // Setup roles
        vm.startPrank(admin);
        userManager.grantRole(userManager.KYC_MANAGER_ROLE(), kycManager);
        userManager.grantRole(userManager.ALLOWLIST_MANAGER_ROLE(), allowlistManager);
        vm.stopPrank();
    }

    // ========================================================================
    // KYC Tests
    // ========================================================================

    function test_setKYC_OK() public {
        vm.startPrank(kycManager);
        vm.expectEmit(true, false, false, true);
        emit KYCUpdate(user1, true);
        userManager.setKYC(user1, true);
        assertTrue(userManager.isKYCed(user1));
        vm.stopPrank();
    }

    function test_setKYC_unauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        userManager.setKYC(user2, true);
        vm.stopPrank();
    }

    function test_setBatchKYC_OK() public {
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;
        bool[] memory statuses = new bool[](2);
        statuses[0] = true;
        statuses[1] = false;

        vm.startPrank(kycManager);
        userManager.setBatchKYC(accounts, statuses);
        assertTrue(userManager.isKYCed(user1));
        assertFalse(userManager.isKYCed(user2));
        vm.stopPrank();
    }

    function test_setBatchKYC_arrayMismatch() public {
        address[] memory accounts = new address[](2);
        bool[] memory statuses = new bool[](1);

        vm.startPrank(kycManager);
        vm.expectRevert();
        userManager.setBatchKYC(accounts, statuses);
        vm.stopPrank();
    }

    // ========================================================================
    // IDENT Tests
    // ========================================================================

    function test_setIDENT_OK() public {
        vm.startPrank(kycManager);
        vm.expectEmit(true, false, false, true);
        emit IDENTUpdate(user1, true);
        userManager.setIDENT(user1, true);
        assertTrue(userManager.isIDENT(user1));
        vm.stopPrank();
    }

    function test_setBatchIDENT_OK() public {
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;
        bool[] memory statuses = new bool[](2);
        statuses[0] = true;
        statuses[1] = false;

        vm.startPrank(kycManager);
        userManager.setBatchIDENT(accounts, statuses);
        assertTrue(userManager.isIDENT(user1));
        assertFalse(userManager.isIDENT(user2));
        vm.stopPrank();
    }

    // ========================================================================
    // AllowList Tests
    // ========================================================================

    function test_setAllowList_OK() public {
        vm.startPrank(allowlistManager);
        vm.expectEmit(true, true, false, true);
        emit AllowListUpdate(user1, 1, 100);
        userManager.setAllowList(user1, 1, 100);
        assertEq(userManager.allowlist(user1, 1), 100);
        vm.stopPrank();
    }

    function test_batchSetAllowList_OK() public {
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;
        uint256[] memory collectionIds = new uint256[](2);
        collectionIds[0] = 1;
        collectionIds[1] = 2;
        uint256[] memory allocations = new uint256[](2);
        allocations[0] = 100;
        allocations[1] = 200;

        vm.startPrank(allowlistManager);
        userManager.batchSetAllowList(accounts, collectionIds, allocations);
        assertEq(userManager.allowlist(user1, 1), 100);
        assertEq(userManager.allowlist(user2, 2), 200);
        vm.stopPrank();
    }

    function test_increaseAllowList_OK() public {
        vm.startPrank(allowlistManager);
        userManager.setAllowList(user1, 1, 100);
        userManager.increaseAllowList(user1, 1, 50);
        assertEq(userManager.allowlist(user1, 1), 150);
        vm.stopPrank();
    }

    function test_decreaseAllowList_OK() public {
        vm.startPrank(allowlistManager);
        userManager.setAllowList(user1, 1, 100);
        userManager.decreaseAllowList(user1, 1, 30);
        assertEq(userManager.allowlist(user1, 1), 70);
        vm.stopPrank();
    }

    // ========================================================================
    // Fuzz Tests
    // ========================================================================

    function testFuzz_setAllowList_OK(address account, uint256 collectionId, uint256 allocation) public {
        vm.assume(account != address(0));

        vm.startPrank(allowlistManager);
        userManager.setAllowList(account, collectionId, allocation);
        assertEq(userManager.allowlist(account, collectionId), allocation);
        vm.stopPrank();
    }

    function testFuzz_increaseAllowList_noOverflow(
        address account,
        uint256 collectionId,
        uint256 initialAmount,
        uint256 delta
    ) public {
        vm.assume(account != address(0));
        vm.assume(initialAmount < type(uint256).max - delta);

        vm.startPrank(allowlistManager);
        userManager.setAllowList(account, collectionId, initialAmount);
        userManager.increaseAllowList(account, collectionId, delta);
        assertEq(userManager.allowlist(account, collectionId), initialAmount + delta);
        vm.stopPrank();
    }

    function testFuzz_increaseAllowList_overflow(
        address account,
        uint256 collectionId,
        uint256 initialAmount,
        uint256 delta
    ) public {
        vm.assume(account != address(0));
        vm.assume(initialAmount > type(uint256).max - delta);

        vm.startPrank(allowlistManager);
        userManager.setAllowList(account, collectionId, initialAmount);
        userManager.increaseAllowList(account, collectionId, delta);
        assertEq(userManager.allowlist(account, collectionId), type(uint256).max);
        vm.stopPrank();
    }

    function testFuzz_decreaseAllowList_noUnderflow(
        address account,
        uint256 collectionId,
        uint256 initialAmount,
        uint256 delta
    ) public {
        vm.assume(account != address(0));
        vm.assume(initialAmount >= delta);

        vm.startPrank(allowlistManager);
        userManager.setAllowList(account, collectionId, initialAmount);
        userManager.decreaseAllowList(account, collectionId, delta);
        assertEq(userManager.allowlist(account, collectionId), initialAmount - delta);
        vm.stopPrank();
    }

    function testFuzz_batchOperations_OK(
        address[10] memory accounts,
        bool[10] memory kycStatuses,
        uint256[10] memory collectionIds,
        uint256[10] memory allocations
    ) public {
        // Assume that all accounts are different
        for (uint256 i = 0; i < 10; i++) {
            for (uint256 j = i + 1; j < 10; j++) {
                vm.assume(accounts[i] != accounts[j]);
            }
        }

        // Convert fixed arrays to dynamic arrays
        address[] memory accountsArray = new address[](10);
        bool[] memory statusArray = new bool[](10);
        uint256[] memory collectionIdsArray = new uint256[](10);
        uint256[] memory allocationsArray = new uint256[](10);

        for (uint256 i = 0; i < 10; i++) {
            accountsArray[i] = accounts[i];
            statusArray[i] = kycStatuses[i];
            collectionIdsArray[i] = collectionIds[i];
            allocationsArray[i] = allocations[i];
        }

        vm.startPrank(kycManager);
        userManager.setBatchKYC(accountsArray, statusArray);
        vm.stopPrank();

        vm.startPrank(allowlistManager);
        userManager.batchSetAllowList(accountsArray, collectionIdsArray, allocationsArray);
        vm.stopPrank();

        // Verify results
        for (uint256 i = 0; i < 10; i++) {
            assertEq(userManager.isKYCed(accountsArray[i]), statusArray[i]);
            assertEq(userManager.allowlist(accountsArray[i], collectionIdsArray[i]), allocationsArray[i]);
        }
    }
}
