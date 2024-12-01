// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

import {IFANtiumUserManager} from "./interfaces/IFANtiumUserManager.sol";
import {FANtiumBaseUpgradable} from "./FANtiumBaseUpgradable.sol";

/**
 * @title FANtium User Manager contract V2.
 * @author MTX studio AG.
 */

contract FANtiumUserManagerV2 is FANtiumBaseUpgradable, IFANtiumUserManager {
    // Roles
    // ========================================================================
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");
    bytes32 public constant ALLOWLIST_MANAGER_ROLE = keccak256("ALLOWLIST_MANAGER_ROLE");

    // ========================================================================
    // State variables
    // ========================================================================
    mapping(address => User) public users;
    mapping(address => bool) private _UNUSED_allowedContracts; // replaced by the ALLOWLIST_MANAGER_ROLE
    address private _UNUSED_trustedForwarder; // handled by the base contract

    // ========================================================================
    // Events
    // ========================================================================
    event KYCUpdate(address indexed account, bool isKYCed);
    event IDENTUpdate(address indexed account, bool isIDENT);
    event AllowListUpdate(address indexed account, uint256 indexed collectionId, uint256 amount);

    // ========================================================================
    // UUPS upgradeable pattern
    // ========================================================================
    function version() public pure override returns (string memory) {
        return "2.0.0";
    }

    function initialize(address _defaultAdmin) public initializer {
        __FANtiumBaseUpgradable_init(_defaultAdmin);
    }

    // ========================================================================
    // Know-your-customer functions
    // ========================================================================
    function _setKYC(address account, bool isKYCed_) internal {
        users[account].isKYCed = isKYCed_;
        emit KYCUpdate(account, isKYCed_);
    }

    function setKYC(address account, bool isKYCed_) external whenNotPaused onlyRoleOrAdmin(KYC_MANAGER_ROLE) {
        _setKYC(account, isKYCed_);
    }

    function setBatchKYC(
        address[] memory accounts,
        bool[] memory isKYCed_
    ) external whenNotPaused onlyRoleOrAdmin(KYC_MANAGER_ROLE) {
        if (accounts.length != isKYCed_.length) {
            revert ArrayLengthMismatch(accounts.length, isKYCed_.length);
        }

        for (uint256 i = 0; i < accounts.length; i++) {
            _setKYC(accounts[i], isKYCed_[i]);
        }
    }

    function isKYCed(address account) public view returns (bool) {
        return users[account].isKYCed;
    }

    // ========================================================================
    // INDENT functions
    // ========================================================================
    function _setIDENT(address account, bool isIDENT_) internal {
        users[account].isIDENT = isIDENT_;
        emit IDENTUpdate(account, isIDENT_);
    }

    function setIDENT(address account, bool isIDENT_) external whenNotPaused onlyRoleOrAdmin(KYC_MANAGER_ROLE) {
        _setIDENT(account, isIDENT_);
    }

    function setBatchIDENT(
        address[] memory accounts,
        bool[] memory isIDENT_
    ) external whenNotPaused onlyRoleOrAdmin(KYC_MANAGER_ROLE) {
        if (accounts.length != isIDENT_.length) {
            revert ArrayLengthMismatch(accounts.length, isIDENT_.length);
        }

        for (uint256 i = 0; i < accounts.length; i++) {
            _setIDENT(accounts[i], isIDENT_[i]);
        }
    }

    function isIDENT(address account) public view returns (bool) {
        return users[account].isIDENT;
    }

    // ========================================================================
    // AllowList functions
    // ========================================================================
    function allowlist(address account, uint256 collectionId) public view returns (uint256) {
        return users[account].contractToAllowListToSpots[collectionId];
    }

    function _setAllowList(address account, uint256 collectionId, uint256 allocation) internal {
        users[account].contractToAllowListToSpots[collectionId] = allocation;
        emit AllowListUpdate(account, collectionId, allocation);
    }

    function setAllowList(
        address account,
        uint256 collectionId,
        uint256 allocation
    ) external whenNotPaused onlyRoleOrAdmin(ALLOWLIST_MANAGER_ROLE) {
        _setAllowList(account, collectionId, allocation);
    }

    function batchSetAllowList(
        address[] memory accounts,
        uint256[] memory collectionIds,
        uint256[] memory allocations
    ) external onlyRoleOrAdmin(ALLOWLIST_MANAGER_ROLE) {
        if (accounts.length != collectionIds.length) {
            revert ArrayLengthMismatch(accounts.length, collectionIds.length);
        }
        if (accounts.length != allocations.length) {
            revert ArrayLengthMismatch(accounts.length, allocations.length);
        }

        for (uint256 i = 0; i < accounts.length; i++) {
            _setAllowList(accounts[i], collectionIds[i], allocations[i]);
        }
    }

    function increaseAllowList(
        address account,
        uint256 collectionId,
        uint256 delta
    ) external whenNotPaused onlyRoleOrAdmin(ALLOWLIST_MANAGER_ROLE) {
        _setAllowList(account, collectionId, allowlist(account, collectionId) + delta);
    }

    function decreaseAllowList(
        address account,
        uint256 collectionId,
        uint256 delta
    ) external whenNotPaused onlyRoleOrAdmin(ALLOWLIST_MANAGER_ROLE) {
        _setAllowList(account, collectionId, allowlist(account, collectionId) - delta);
    }
}
