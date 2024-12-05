// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { StringsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import { IFANtiumUserManager } from "src/interfaces/IFANtiumUserManager.sol";
import { IFANtiumNFT } from "src/interfaces/IFANtiumNFT.sol";
/**
 * @title FANtium User Manager contract V2.
 * @notice Used to manage user information such as KYC status, IDENT status, and allowlist allocations.
 * @dev KYC is "soft verification" and IDENT is "hard verification".
 * @author Mathieu Bour - FANtium, based on previous work by MTX Studio AG
 *
 * @custom:oz-upgrades-from FantiumUserManager
 */

contract FANtiumUserManagerV2 is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    IFANtiumUserManager
{
    using StringsUpgradeable for uint256;

    // ========================================================================
    // Roles
    // ========================================================================
    bytes32 public constant FORWARDER_ROLE = keccak256("FORWARDER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");
    bytes32 public constant ALLOWLIST_MANAGER_ROLE = keccak256("ALLOWLIST_MANAGER_ROLE");

    // ========================================================================
    // State variables
    // ========================================================================
    mapping(address => User) public users;

    /**
     * @dev deprecated: replaced by the ALLOWLIST_MANAGER_ROLE
     * @custom:oz-renamed-from allowedContracts
     */
    mapping(address => bool) private UNUSED_allowedContracts;

    /**
     * @custom:oz-renamed-from trustedForwarder
     */
    address private UNUSED_trustedForwarder;

    IFANtiumNFT public fantiumNFT;

    // ========================================================================
    // Events
    // ========================================================================
    event KYCUpdate(address indexed account, bool isKYCed);
    event IDENTUpdate(address indexed account, bool isIDENT);
    event AllowListUpdate(address indexed account, uint256 indexed collectionId, uint256 amount);

    // ========================================================================
    // UUPS upgradeable pattern
    // ========================================================================
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /**
     * @notice Implementation of the upgrade authorization logic
     * @dev Restricted to the DEFAULT_ADMIN_ROLE
     */
    function _authorizeUpgrade(address) internal view override {
        _checkRole(DEFAULT_ADMIN_ROLE);
    }

    // ========================================================================
    // Access control
    // ========================================================================
    modifier onlyRoleOrAdmin(bytes32 role) {
        _checkRoleOrAdmin(role);
        _;
    }

    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    modifier onlyManagerOrAdmin() {
        _checkRoleOrAdmin(MANAGER_ROLE);
        _;
    }

    function _checkRoleOrAdmin(bytes32 role) internal view virtual {
        if (!hasRole(role, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(msg.sender),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    // ========================================================================
    // Pause
    // ========================================================================
    /**
     * @notice Update contract pause status to `_paused`.
     */
    function pause() external onlyManagerOrAdmin {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */
    function unpause() external onlyManagerOrAdmin {
        _unpause();
    }

    // ========================================================================
    // Setters
    // ========================================================================
    function setFANtiumNFT(IFANtiumNFT _fantiumNFT) external onlyAdmin {
        fantiumNFT = _fantiumNFT;
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
    )
        external
        whenNotPaused
        onlyRoleOrAdmin(KYC_MANAGER_ROLE)
    {
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
    )
        external
        whenNotPaused
        onlyRoleOrAdmin(KYC_MANAGER_ROLE)
    {
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
        return users[account].contractToAllowlistToSpots[address(fantiumNFT)][collectionId];
    }

    function _setAllowList(address account, uint256 collectionId, uint256 allocation) internal {
        users[account].contractToAllowlistToSpots[address(fantiumNFT)][collectionId] = allocation;
        emit AllowListUpdate(account, collectionId, allocation);
    }

    function setAllowList(
        address account,
        uint256 collectionId,
        uint256 allocation
    )
        external
        whenNotPaused
        onlyRoleOrAdmin(ALLOWLIST_MANAGER_ROLE)
    {
        _setAllowList(account, collectionId, allocation);
    }

    function batchSetAllowList(
        address[] memory accounts,
        uint256[] memory collectionIds,
        uint256[] memory allocations
    )
        external
        onlyRoleOrAdmin(ALLOWLIST_MANAGER_ROLE)
    {
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

    /**
     * @notice Increases the allowlist for an account and collection.
     * @dev If the result is greater than type(uint256).max, it will be set to type(uint256).max.
     * @param account The account to increase the allowlist for.
     * @param collectionId The collection to increase the allowlist for.
     * @param delta The amount to increase the allowlist by.
     */
    function increaseAllowList(
        address account,
        uint256 collectionId,
        uint256 delta
    )
        external
        whenNotPaused
        onlyRoleOrAdmin(ALLOWLIST_MANAGER_ROLE)
    {
        uint256 current = allowlist(account, collectionId);
        uint256 max = type(uint256).max;
        _setAllowList(account, collectionId, (delta > max - current) ? max : current + delta);
    }

    /**
     * @notice Decreases the allowlist for an account and collection.
     * @dev If the current allowlist is less than the delta, it will be set to 0.
     * @param account The account to decrease the allowlist for.
     * @param collectionId The collection to decrease the allowlist for.
     * @param delta The amount to decrease the allowlist by.
     */
    function decreaseAllowList(
        address account,
        uint256 collectionId,
        uint256 delta
    )
        external
        whenNotPaused
        onlyRoleOrAdmin(ALLOWLIST_MANAGER_ROLE)
    {
        uint256 current = allowlist(account, collectionId);
        _setAllowList(account, collectionId, current < delta ? 0 : current - delta);
    }
}
