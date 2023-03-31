// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../claiming/FantiumClaimingV1.sol";
import "../interfaces/IFantiumNFT.sol";
import "../interfaces/IFantiumUserManager.sol";

/**
 * @title FANtium User Manager contract V1.
 * @author MTX studio AG.
 */

contract FantiumUserManager is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    IFantiumUserManager
{
    using StringsUpgradeable for uint256;

    mapping(address => User) public users;
    mapping(address => bool) public allowedContracts;

    uint256 constant ONE_MILLION = 1_000_000;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE =
        keccak256("PLATFORM_MANAGER_ROLE");
    // generic event fields
    bytes32 constant FIELD_PLATFORM_CONFIG = "platform address config";
    bytes32 constant FIELD_CONTRACTS_ALLOWED_CHANGE =
        "contracts added or removed";
    bytes32 constant FIELD_KYC_CHANGE = "KYC added or removed";
    bytes32 constant FIELD_IDENT_CHANGE = "IDENT added or removed";
    bytes32 constant FIELD_ALLOWLIST_CHANGE = "allowlist added or removed";

    struct User {
        bool isKYCed;
        bool isIDENT;
        mapping(address => mapping(uint256 => uint256)) contractToAllowlistToSpots;
    }

    address private trustedForwarder;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PlatformUpdate(bytes32 indexed _update);
    event KYCUpdate(address indexed _address, bytes32 indexed _update);
    event IDENTUpdate(address indexed _address, bytes32 indexed _update);
    event ALUpdate(
        address indexed _contract,
        uint256 indexed _collectionId,
        address indexed _address,
        bytes32 _update
    );

    /*//////////////////////////////////////////////////////////////
                            MODIFERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyValidAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier onlyManager() {
        require(hasRole(PLATFORM_MANAGER_ROLE, msg.sender), "Only manager");
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            UUPS UPGRADEABLE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes contract.
     * @param _tokenName Name of token.
     * @param _tokenSymbol Token symbol.
     * max(uint248) to avoid overflow when adding to it.
     */
    ///@dev no constructor in upgradable contracts. Instead we have initializers
    function initialize(
        address _defaultAdmin,
        address _nftContract,
        address _claimingContract,
        address _trustedForwarder
    ) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(UPGRADER_ROLE, _defaultAdmin);
        allowedContracts[_nftContract] = true;
        allowedContracts[_claimingContract] = true;
        trustedForwarder = _trustedForwarder;
    }

    /// @notice upgrade authorization logic
    /// @dev required by the OZ UUPS module
    /// @dev adds onlyRole(UPGRADER_ROLE) requirement
    function _authorizeUpgrade(
        address
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                                 KYC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add address to KYC list.
     * @param _address address to be added to KYC list.
     */
    function addBatchtoKYC(
        address[] memory _address
    ) external whenNotPaused onlyManager {
        for (uint256 i = 0; i < _address.length; i++) {
            addAddressToKYC(_address[i]);
        }
    }

    /**
     * @notice Add address to KYC list.
     * @param _address address to be added to KYC list.
     */
    function addAddressToKYC(
        address _address
    ) public whenNotPaused onlyManager {
        if (users[_address].isKYCed == false) {
            users[_address].isKYCed = true;
            emit KYCUpdate(_address, FIELD_KYC_CHANGE);
        }
    }

    /**
     * @notice Remove address from KYC list.
     * @param _address address to be removed from KYC list.
     */
    function removeAddressFromKYC(
        address _address
    ) external whenNotPaused onlyManager {
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

    function addBatchtoIDENT(
        address[] memory _address
    ) external whenNotPaused onlyManager {
        for (uint256 i = 0; i < _address.length; i++) {
            addAddressToIDENT(_address[i]);
        }
    }

    /**
     * @notice Add address to KYC list.
     * @param _address address to be added to KYC list.
     */
    function addAddressToIDENT(
        address _address
    ) public whenNotPaused onlyManager {
        users[_address].isIDENT = true;
        emit IDENTUpdate(_address, FIELD_IDENT_CHANGE);
    }

    /**
     * @notice Remove address from KYC list.
     * @param _address address to be removed from KYC list.
     */
    function removeAddressFromIDENT(
        address _address
    ) external whenNotPaused onlyManager {
        users[_address].isIDENT = false;
        emit IDENTUpdate(_address, FIELD_IDENT_CHANGE);
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
    ) public whenNotPaused onlyManager {
        require(allowedContracts[_contractAddress], "Only allowed Contract");
        require(
            IFantiumNFT(_contractAddress).getCollectionExists(_collectionId),
            "Collection does not exist"
        );
        require(
            _addresses.length == _increaseAllocations.length,
            "FantiumUserManagerV1: Array length mismatch"
        );
        for (uint256 i = 0; i < _addresses.length; i++) {
            users[_addresses[i]].contractToAllowlistToSpots[_contractAddress][
                _collectionId
            ] += _increaseAllocations[i];
            emit ALUpdate(
                _contractAddress,
                _collectionId,
                _addresses[i],
                FIELD_ALLOWLIST_CHANGE
            );
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
                allowedContracts[msg.sender],
            "Only manager or allowed Contract"
        );
        require(allowedContracts[_contractAddress], "Only allowed Contract");

        users[_address].contractToAllowlistToSpots[_contractAddress][
            _collectionId
        ] > _reduceAllocation
            ? users[_address].contractToAllowlistToSpots[_contractAddress][
                _collectionId
            ] -= _reduceAllocation
            : users[_address].contractToAllowlistToSpots[_contractAddress][
                _collectionId
            ] = 0;
        emit ALUpdate(
            _contractAddress,
            _collectionId,
            _address,
            FIELD_ALLOWLIST_CHANGE
        );
        return
            users[_address].contractToAllowlistToSpots[_contractAddress][
                _collectionId
            ];
    }

    function hasAllowlist(
        address _contractAddress,
        uint256 _collectionId,
        address _address
    ) public view returns (uint256) {
        return
            users[_address].contractToAllowlistToSpots[_contractAddress][
                _collectionId
            ];
    }

    /*///////////////////////////////////////////////////////////////
                        PLATFORM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update contract pause status to `_paused`.
     */

    function pause() external onlyRole(PLATFORM_MANAGER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */

    function unpause() external onlyRole(PLATFORM_MANAGER_ROLE) {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIMING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice set NFT contract addresses
     */

    function addAllowedConctract(
        address _contractAddress
    ) public onlyRole(PLATFORM_MANAGER_ROLE) {
        require(_contractAddress != address(0), "No null address allowed");
        allowedContracts[_contractAddress] = true;
        emit PlatformUpdate(FIELD_CONTRACTS_ALLOWED_CHANGE);
    }

    /**
     * @notice set NFT contract addresses
     */

    function removeAllowedConctract(
        address _contractAddress
    ) public onlyRole(PLATFORM_MANAGER_ROLE) {
        require(_contractAddress != address(0), "No null address allowed");
        allowedContracts[_contractAddress] = false;
        emit PlatformUpdate(FIELD_CONTRACTS_ALLOWED_CHANGE);
    }

    /*///////////////////////////////////////////////////////////////
                            ERC2771
    //////////////////////////////////////////////////////////////*/

    function setTrustedForwarder(
        address forwarder
    ) external onlyRole(UPGRADER_ROLE) {
        trustedForwarder = forwarder;
        emit PlatformUpdate(FIELD_PLATFORM_CONFIG);
    }

    function isTrustedForwarder(
        address forwarder
    ) public view virtual returns (bool) {
        return forwarder == trustedForwarder;
    }

    function _msgSender()
        internal
        view
        virtual
        override
        returns (address sender)
    {
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

    function _msgData()
        internal
        view
        virtual
        override
        returns (bytes calldata)
    {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
}
