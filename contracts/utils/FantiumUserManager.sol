// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../claiming/FantiumClaimingV1.sol";

/**
 * @title FANtium Allowlist Manager contract V1.
 * @author MTX studio AG.
 */

contract FantiumUserManager is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    using StringsUpgradeable for uint256;

    mapping(address => User) public users;
    mapping(address => bool) public allowedContracts;
    address public FantiumClaimContract;
    address public FantiumNFTContract;

    uint256 constant ONE_MILLION = 1_000_000;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE =
        keccak256("PLATFORM_MANAGER_ROLE");

    struct User {
        bool isKYCed;
        bool isIDENT;
        mapping(address => mapping(uint256 => uint256)) contractToAllowlistToSpots;
    }


    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PlatformUpdated(bytes32 indexed _field);
    event AddressAddedToKYC(address indexed _address);
    event AddressRemovedFromKYC(address indexed _address);
    event AddressAddedToIDENT(address indexed _address);
    event AddressRemovedFromIDENT(address indexed _address);
    event AddressAddedToAllowList(
        uint256 collectionId,
        address indexed _address
    );
    event AddressRemovedFromAllowList(
        uint256 collectionId,
        address indexed _address
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

    modifier onlyAllowedContract(address _contract) {
        require(allowedContracts[_contract], "Only allowed contracts");
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
        address _defaultAdmin
    ) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(UPGRADER_ROLE, _defaultAdmin);

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
    ) external whenNotPaused onlyManager
    {
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
    ) 
    public
    whenNotPaused 
    onlyManager {
        users[_address].isKYCed = true;
        emit AddressAddedToKYC(_address);
    }

    /**
     * @notice Remove address from KYC list.
     * @param _address address to be removed from KYC list.
     */
    function removeAddressFromKYC(
        address _address
    ) external whenNotPaused onlyManager {
        users[_address].isKYCed = false;
        emit AddressRemovedFromKYC(_address);
    }

    /**
     * @notice Check if address is KYCed.
     * @param _address address to be checked.
     * @return isKYCed true if address is KYCed.
     */
    function isAddressKYCed(address _address) public view returns (bool) {
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
        emit AddressAddedToIDENT(_address);
    }

    /**
     * @notice Remove address from KYC list.
     * @param _address address to be removed from KYC list.
     */
    function removeAddressFromIDENT(
        address _address
    ) external whenNotPaused onlyManager {
        users[_address].isIDENT = false;
        emit AddressRemovedFromIDENT(_address);
    }

        /**
     * @notice Check if address is KYCed.
     * @param _address address to be checked.
     * @return isKYCed true if address is KYCed.
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
    )
        public
        whenNotPaused
        onlyRole(PLATFORM_MANAGER_ROLE)
        onlyAllowedContract(_contractAddress)
    {
        
        for (uint256 i = 0; i < _addresses.length; i++) {    
            users[_addresses[i]].contractToAllowlistToSpots[_contractAddress][_collectionId] += _increaseAllocations[i];
            emit AddressAddedToAllowList(_collectionId, _addresses[i]);
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
    )
        public
        whenNotPaused
        onlyRole(PLATFORM_MANAGER_ROLE)
        onlyAllowedContract(_contractAddress)
    {

        users[_address].contractToAllowlistToSpots[_contractAddress][_collectionId] > _reduceAllocation ? users[_address].contractToAllowlistToSpots[_contractAddress][_collectionId] -= _reduceAllocation : users[_address].contractToAllowlistToSpots[_contractAddress][_collectionId] = 0;
        emit AddressRemovedFromAllowList(_collectionId, _address);
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
     * @notice set Claim contract address
     */

    function updateClaimContract(address _claimContract)
        public
        whenNotPaused
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        FantiumClaimContract = _claimContract;
    }

    /**
     * @notice set Claim contract address
     */

    function updateNFTConctract(address _nftContract)
        public
        whenNotPaused
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        FantiumNFTContract = _nftContract;
    }


    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/
}
