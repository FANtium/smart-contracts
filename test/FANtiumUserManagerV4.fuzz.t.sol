// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { FANtiumUserManagerV4 } from "src/FANtiumUserManagerV4.sol";
import { IFANtiumUserManager } from "src/interfaces/IFANtiumUserManager.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumUserManagerFactory } from "test/setup/FANtiumUserManagerFactory.sol";

contract FANtiumUserManagerV4FuzzTest is BaseTest, FANtiumUserManagerFactory {
    uint256 public constant MAX_ARRAY_LENGTH = 10_000;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Need to copy the events from the FANtiumUserManagerV4 contract
    event KYCUpdate(address indexed account, bool isKYCed);
    event IDENTUpdate(address indexed account, bool isIDENT);
    event AllowListUpdate(address indexed account, uint256 indexed collectionId, uint256 amount);

    function setUp() public virtual override {
        address implementation = address(new FANtiumUserManagerV4());
        address proxy = UnsafeUpgrades.deployUUPSProxy(
            implementation, abi.encodeCall(FANtiumUserManagerV4.initialize, (userManager_admin))
        );
        userManager = FANtiumUserManagerV4(proxy);

        // Setup roles
        vm.startPrank(userManager_admin);
        userManager.grantRole(userManager.KYC_MANAGER_ROLE(), userManager_kycManager);
        userManager.grantRole(userManager.ALLOWLIST_MANAGER_ROLE(), userManager_allowlistManager);
        vm.stopPrank();
    }

    function testFuzz_setBatchIDENT_arrayMismatch(uint256 x, uint256 y) public {
        vm.assume(x != y && 0 < x && x < 10_000 && 0 < y && y < 10_000);
        address[] memory accounts = new address[](x);
        bool[] memory statuses = new bool[](y);

        vm.startPrank(userManager_kycManager);
        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumUserManager.ArrayLengthMismatch.selector, accounts.length, statuses.length)
        );
        userManager.setBatchIDENT(accounts, statuses);
        vm.stopPrank();
    }

    function testFuzz_setAllowList_OK(address account, uint256 collectionId, uint256 allocation) public {
        vm.assume(account != address(0));

        vm.startPrank(userManager_allowlistManager);
        userManager.setAllowList(account, collectionId, allocation);
        assertEq(userManager.allowlist(account, collectionId), allocation);
        vm.stopPrank();
    }

    function testFuzz_increaseAllowList_noOverflow(
        address account,
        uint256 collectionId,
        uint256 initialAmount,
        uint256 delta
    )
        public
    {
        vm.assume(account != address(0));
        vm.assume(initialAmount < type(uint256).max - delta);

        vm.startPrank(userManager_allowlistManager);
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
    )
        public
    {
        uint256 max = type(uint256).max;
        vm.assume(account != address(0));
        vm.assume(delta > 0);
        initialAmount = bound(initialAmount, max - delta, max);

        vm.startPrank(userManager_allowlistManager);
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
    )
        public
    {
        vm.assume(account != address(0));
        vm.assume(initialAmount >= delta);

        vm.startPrank(userManager_allowlistManager);
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
    )
        public
    {
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

        vm.startPrank(userManager_kycManager);
        userManager.setBatchKYC(accountsArray, statusArray);
        vm.stopPrank();

        vm.startPrank(userManager_allowlistManager);
        userManager.batchSetAllowList(accountsArray, collectionIdsArray, allocationsArray);
        vm.stopPrank();

        // Verify results
        for (uint256 i = 0; i < 10; i++) {
            assertEq(userManager.isKYCed(accountsArray[i]), statusArray[i]);
            assertEq(userManager.allowlist(accountsArray[i], collectionIdsArray[i]), allocationsArray[i]);
        }
    }
}
