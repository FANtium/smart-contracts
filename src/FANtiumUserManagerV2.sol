// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "../claiming/FANtiumClaimingV1.sol";
import "../interfaces/IFANtiumNFT.sol";
import "../interfaces/IFANtiumUserManager.sol";

/**
 * @title FANtium User Manager contract V2.
 * @author MTX studio AG.
 */

contract FANtiumUserManagerV2 is FANtiumBaseUpgradable, IFANtiumUserManager {
    using StringsUpgradeable for uint256;

    // ========================================================================
    // Constants
    // ========================================================================
    string public constant VERSION = "5.0.0";
    uint256 public constant ONE_MILLION = 1_000_000;

    // Roles
    // ========================================================================
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE = keccak256("PLATFORM_MANAGER_ROLE");
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");

    // Fields
    // ========================================================================
    bytes32 public constant FIELD_PLATFORM_CONFIG = "platform address config";
    bytes32 public constant FIELD_CONTRACTS_ALLOWED_CHANGE = "contracts added or removed";
    bytes32 public constant FIELD_KYC_CHANGE = "KYC added or removed";
    bytes32 public constant FIELD_IDENT_CHANGE = "IDENT added or removed";
    bytes32 public constant FIELD_ALLOWLIST_CHANGE = "allowlist added or removed";

    // ========================================================================
    // State variables
    // ========================================================================
    mapping(address => User) public users;
    mapping(address => bool) public allowedContracts;
    address public trustedForwarder;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PlatformUpdate(bytes32 indexed _update);
    event KYCUpdate(address indexed _address, bytes32 indexed _update);
    event IDENTUpdate(address indexed _address, bytes32 indexed _update);
    event ALUpdate(address indexed _contract, uint256 indexed _collectionId, address indexed _address, bytes32 _update);

    /*//////////////////////////////////////////////////////////////
                            MODIFERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyUpgrader() {
        require(hasRole(UPGRADER_ROLE, msg.sender), "Only upgrader");
        _;
    }

    modifier onlyPlatformManager() {
        require(hasRole(PLATFORM_MANAGER_ROLE, msg.sender), "Only platform manager");
        _;
    }

    modifier onlyManagers() {
        require(hasRole(PLATFORM_MANAGER_ROLE, msg.sender) || hasRole(KYC_MANAGER_ROLE, _msgSender()), "Only managers");
        _;
    }

    // ========================================================================
    // UUPS upgradeable pattern
    // ========================================================================
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    function version() public pure override returns (string memory) {
        return "2.0.0";
    }

    function initialize(
        address _defaultAdmin,
        address _fantiumNFTContract,
        address _claimingContract,
        address _trustedForwarder
    ) public initializer {
        __FANtiumBaseUpgradable_init(_defaultAdmin);
    }

    /**
     * @notice Initializes contract.
     * @param _tokenName Name of token.
     * @param _tokenSymbol Token symbol.
     * max(uint248) to avoid overflow when adding to it.
     */
    ///@dev no constructor in upgradable contracts. Instead we have initializers
    function initialize(
        address _defaultAdmin,
        address _fantiumNFTContract,
        address _claimingContract,
        address _trustedForwarder
    ) public initializer {
        require(
            _defaultAdmin != address(0) && _fantiumNFTContract != address(0) && _claimingContract != address(0),
            "Invalid addresses"
        );
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(UPGRADER_ROLE, _defaultAdmin);
        allowedContracts[_fantiumNFTContract] = true;
        allowedContracts[_claimingContract] = true;
        trustedForwarder = _trustedForwarder;
    }

    /**
     * @notice Implementation of the upgrade authorization logic
     * @dev Restricted to the UPGRADER_ROLE
     */
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ========================================================================
    // ERC2771, single trusted forwarder
    // ========================================================================
    function setTrustedForwarder(address _trustedForwarder) public onlyRole(UPGRADER_ROLE) {
        trustedForwarder = _trustedForwarder;
    }

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == trustedForwarder;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 KYC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add address to KYC list.
     * @param _address address to be added to KYC list.
     */
    function addBatchtoKYC(address[] memory _address) external whenNotPaused onlyManagers {
        for (uint256 i = 0; i < _address.length; i++) {
            addAddressToKYC(_address[i]);
        }
    }

    /**
     * @notice Add address to KYC list.
     * @param _address address to be added to KYC list.
     */
    function addAddressToKYC(address _address) public whenNotPaused onlyManagers {
        if (users[_address].isKYCed == false) {
            users[_address].isKYCed = true;
            emit KYCUpdate(_address, FIELD_KYC_CHANGE);
        }
    }

    /**
     * @notice Remove address from KYC list.
     * @param _address address to be removed from KYC list.
     */
    function removeAddressFromKYC(address _address) external whenNotPaused onlyManagers {
        if (users[_address].isKYCed) {
            users[_address].isKYCed = false;
            emit KYCUpdate(_address, FIELD_KYC_CHANGE);
        }
    }

    /**
     * @notice Check if address is KYCed.
     * @param _address address to be checked.
     * @return isKYCed true if address is KYCed.
     */
    function isAddressKYCed(address _address) external view returns (bool) {
        return users[_address].isKYCed;
    }

    /*//////////////////////////////////////////////////////////////
                                 IDENT
    //////////////////////////////////////////////////////////////*/

    function addBatchtoIDENT(address[] memory _address) external whenNotPaused onlyManagers {
        for (uint256 i = 0; i < _address.length; i++) {
            addAddressToIDENT(_address[i]);
        }
    }

    /**
     * @notice Add address to KYC list.
     * @param _address address to be added to KYC list.
     */
    function addAddressToIDENT(address _address) public whenNotPaused onlyManagers {
        if (users[_address].isIDENT == false) {
            users[_address].isIDENT = true;
            emit IDENTUpdate(_address, FIELD_IDENT_CHANGE);
        }
    }

    /**
     * @notice Remove address from KYC list.
     * @param _address address to be removed from KYC list.
     */
    function removeAddressFromIDENT(address _address) external whenNotPaused onlyManagers {
        if (users[_address].isIDENT == true) {
            users[_address].isIDENT = false;
            emit IDENTUpdate(_address, FIELD_IDENT_CHANGE);
        }
    }

    /**
     * @notice Check if address is IDENT.
     * @param _address address to be checked.
     * @return isIDEN true if address is IDENT.
     */
    function isAddressIDENT(address _address) public view returns (bool) {
        return users[_address].isIDENT;
    }

    /*//////////////////////////////////////////////////////////////
                            ALLOW LIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add address to allow list.
     * @param _collectionId collection ID.
     * @param _addresses addresses to add to allow list.
     * @param _increaseAllocations allocation to the address.
     */
    function batchAllowlist(
        uint256 _collectionId,
        address _contractAddress,
        address[] memory _addresses,
        uint256[] memory _increaseAllocations
    ) public whenNotPaused onlyManagers {
        require(allowedContracts[_contractAddress], "Only allowed Contract");
        require(IFANtiumNFT(_contractAddress).getCollectionExists(_collectionId), "Collection does not exist");
        require(_addresses.length == _increaseAllocations.length, "FANtiumUserManagerV1: Array length mismatch");
        for (uint256 i = 0; i < _addresses.length; i++) {
            users[_addresses[i]].contractToAllowlistToSpots[_contractAddress][_collectionId] += _increaseAllocations[i];
            emit ALUpdate(_contractAddress, _collectionId, _addresses[i], FIELD_ALLOWLIST_CHANGE);
        }
    }

    /**
     * @notice Remove address from allow list.
     * @param _collectionId collection ID.
     * @param _address address to be removed from allow list.
     * @param _reduceAllocation allocation to the address.
     */
    function reduceAllowListAllocation(
        uint256 _collectionId,
        address _contractAddress,
        address _address,
        uint256 _reduceAllocation
    ) external whenNotPaused returns (uint256) {
        require(
            hasRole(PLATFORM_MANAGER_ROLE, msg.sender) ||
                allowedContracts[msg.sender] ||
                hasRole(KYC_MANAGER_ROLE, msg.sender),
            "Only manager or allowed Contract"
        );
        require(allowedContracts[_contractAddress], "Only allowed Contract");
        require(IFANtiumNFT(_contractAddress).getCollectionExists(_collectionId), "Collection does not exist");

        users[_address].contractToAllowlistToSpots[_contractAddress][_collectionId] > _reduceAllocation
            ? users[_address].contractToAllowlistToSpots[_contractAddress][_collectionId] -= _reduceAllocation
            : users[_address].contractToAllowlistToSpots[_contractAddress][_collectionId] = 0;
        emit ALUpdate(_contractAddress, _collectionId, _address, FIELD_ALLOWLIST_CHANGE);
        return users[_address].contractToAllowlistToSpots[_contractAddress][_collectionId];
    }

    function hasAllowlist(
        address _contractAddress,
        uint256 _collectionId,
        address _address
    ) public view returns (uint256) {
        return users[_address].contractToAllowlistToSpots[_contractAddress][_collectionId];
    }

    /*///////////////////////////////////////////////////////////////
                        PLATFORM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update contract pause status to `_paused`.
     */

    function pause() external onlyPlatformManager {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */

    function unpause() external onlyPlatformManager {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice set NFT contract addresses
     */

    function addAllowedConctract(address _contractAddress) public onlyUpgrader {
        require(_contractAddress != address(0), "No null address allowed");
        if (!allowedContracts[_contractAddress]) {
            allowedContracts[_contractAddress] = true;
            emit PlatformUpdate(FIELD_CONTRACTS_ALLOWED_CHANGE);
        }
    }

    /**
     * @notice set NFT contract addresses
     */

    function removeAllowedConctract(address _contractAddress) public onlyUpgrader {
        require(_contractAddress != address(0), "No null address allowed");
        if (allowedContracts[_contractAddress]) {
            allowedContracts[_contractAddress] = false;
            emit PlatformUpdate(FIELD_CONTRACTS_ALLOWED_CHANGE);
        }
    }
}
