// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./interfaces/IFantiumNFT.sol";

/**
 * @title FANtium ERC721 contract V1.
 * @author MTX stuido AG.
 */

contract FantiumMinterV1 is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable
{
    using StringsUpgradeable for uint256;

    /// ACM
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE =
        keccak256("PLATFORM_MANAGER_ROLE");

    mapping(uint256 => mapping(address => bool)) public collectionIdToAllowList;
    mapping(address => bool) public kycedAddresses;
    uint256 constant ONE_MILLION = 1_000_000;

    address public fantiumNFTContractAddress;
    IFantiumNFT private fantiumNFTContract;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(address indexed _to, uint256 indexed _tokenId);
    event PlatformUpdated(bytes32 indexed _field);
    event MinterUpdated(address indexed _currentMinter);
    event AddressAddedToKYC(address indexed _address);
    event AddressRemovedFromKYC(address indexed _address);
    event AddressAddedToAllowList(
        uint256 collectionId,
        address indexed _address
    );
    event AddressRemovedFromAllowList(
        uint256 collectionId,
        address indexed _address
    );

    event FantiumNFTContractUpdated(address indexed _fantiumNFTContract);

    /*//////////////////////////////////////////////////////////////
                                 MODIFERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyKycManager() {
        require(
            hasRole(KYC_MANAGER_ROLE, msg.sender) ||
                hasRole(PLATFORM_MANAGER_ROLE, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Only KYC updater"
        );
        _;
    }

    modifier onlyPlatformManager() {
        require(
            hasRole(PLATFORM_MANAGER_ROLE, msg.sender) ||
                hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Only platform manager"
        );
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
    function initialize() public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(KYC_MANAGER_ROLE, msg.sender);
        _grantRole(PLATFORM_MANAGER_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    /// @notice upgrade authorization logic
    /// @dev required by the OZ UUPS module
    /// @dev adds onlyRole(UPGRADER_ROLE) requirement
    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

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
    function addAddressToKYC(address _address) external onlyKycManager {
        kycedAddresses[_address] = true;
        emit AddressAddedToKYC(_address);
    }

    /**
     * @notice Remove address from KYC list.
     * @param _address address to be removed from KYC list.
     */
    function removeAddressFromKYC(address _address) external onlyKycManager {
        kycedAddresses[_address] = false;
        emit AddressRemovedFromKYC(_address);
    }

    /**
     * @notice Check if address is KYCed.
     * @param _address address to be checked.
     * @return isKYCed true if address is KYCed.
     */
    function isAddressKYCed(address _address) public view returns (bool) {
        return kycedAddresses[_address];
    }

    /*//////////////////////////////////////////////////////////////
                            ALLOW LIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add address to allow list.
     * @param _collectionId collection ID.
     * @param _address address to be added to allow list.
     */
    function addAddressToAllowList(uint256 _collectionId, address _address)
        public
        onlyPlatformManager
    {
        collectionIdToAllowList[_collectionId][_address] = true;
        emit AddressAddedToAllowList(_collectionId, _address);
    }

    /**
     * @notice Remove address from allow list.
     * @param _collectionId collection ID.
     * @param _address address to be removed from allow list.
     */
    function removeAddressFromAllowList(uint256 _collectionId, address _address)
        public
        onlyPlatformManager
    {
        collectionIdToAllowList[_collectionId][_address] = false;
        emit AddressRemovedFromAllowList(_collectionId, _address);
    }

    /**
     * @notice Check if address is on allow list.
     * @param _collectionId collection ID.
     * @param _address address to be checked.
     * @return isOnAllowList true if address is on allow list.
     */
    function isAddressOnAllowList(uint256 _collectionId, address _address)
        public
        view
        returns (bool)
    {
        return collectionIdToAllowList[_collectionId][_address];
    }

    /*//////////////////////////////////////////////////////////////
                                 MINTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints a token from collection `_collectionId` and sets the
     * token's owner to `_to`.
     * @param _to Address to be the minted token's owner.
     * @param _collectionId collection ID to mint a token on.
     */
    function mint(address _to, uint256 _collectionId)
        public
        payable
        returns (uint256 tokenId_)
    {
        /// CHECKS
        // nft contract address must be set
        require(fantiumNFTContractAddress != address(0), "Fantium NFT not set");

        // sender must be KYCed or Admin or Manager
        if (
            !hasRole(PLATFORM_MANAGER_ROLE, msg.sender) ||
            !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
        ) {
            require(isAddressKYCed(msg.sender), "Address not KYCed");
        }

        IFantiumNFT.Collection memory collection = fantiumNFTContract
            .getCollection(_collectionId);
        
        // sender must be on allow list or Admin or Manager if collection is paused
        if (
            !hasRole(PLATFORM_MANAGER_ROLE, msg.sender) &&
            !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
        ) {
            require(
                !collection.paused ||
                    isAddressOnAllowList(_collectionId, msg.sender),
                "Purchases are paused and not on allow list"
            );
        }

        // load invocations into memory
        uint24 invocationsBefore = collection.invocations;
        uint24 invocationsAfter;
        unchecked {
            // invocationsBefore guaranteed <= maxInvocations <= 1_000_000,
            // 1_000_000 << max uint24, so no possible overflow
            invocationsAfter = invocationsBefore + 1;
        }
        uint24 maxInvocations = collection.tier.maxInvocations;
        require(
            invocationsBefore < maxInvocations,
            "Must not exceed max invocations"
        );

        // load price of token into memory
        uint256 _pricePerTokenInWei = collection.tier.priceInWei;
        // check if msg.value is more or equal to price of token
        require(
            msg.value >= _pricePerTokenInWei,
            "Must send minimum value to mint!"
        );

        /// EFFECTS
        // increment collection's invocations
        collection.invocations = invocationsAfter;
        uint256 thisTokenId;
        unchecked {
            // invocationsBefore is uint24 << max uint256. In production use,
            // _collectionId * ONE_MILLION must be << max uint256, otherwise
            // tokenIdTocollectionId function become invalid.
            // Therefore, no risk of overflow
            thisTokenId = (_collectionId * ONE_MILLION) + invocationsBefore;
        }
        //set allowlist to false
        collectionIdToAllowList[_collectionId][_to] = false;

        // INTERACTIONS
        fantiumNFTContract.mintTo(msg.sender, thisTokenId);
        _splitFundsETH(_collectionId, _pricePerTokenInWei);

        return thisTokenId;
    }

    /**
     * @dev splits ETH funds between sender (if refund),
     * FANtium, and athlete for a token purchased on
     * collection `_collectionId`.
     */
    function _splitFundsETH(uint256 _collectionId, uint256 _pricePerTokenInWei)
        internal
    {
        if (msg.value > 0) {
            bool success_;
            // send refund to sender
            uint256 refund = msg.value - _pricePerTokenInWei;
            if (refund > 0) {
                (success_, ) = msg.sender.call{value: refund}("");
                require(success_, "Refund failed");
            }
            // split remaining funds between FANtium and athlete
            (
                uint256 fantiumRevenue_,
                address payable fantiumAddress_,
                uint256 athleteRevenue_,
                address payable athleteAddress_
            ) = fantiumNFTContract.getPrimaryRevenueSplits(
                    _collectionId,
                    _pricePerTokenInWei
                );
            // FANtium payment
            if (fantiumRevenue_ > 0) {
                (success_, ) = fantiumAddress_.call{value: fantiumRevenue_}("");
                require(success_, "FANtium payment failed");
            }
            // athlete payment
            if (athleteRevenue_ > 0) {
                (success_, ) = athleteAddress_.call{value: athleteRevenue_}("");
                require(success_, "Artist payment failed");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set FANtium NFT contract address.
     * @param _fantiumNFTContractAddress FANtium NFT contract address.
     */
    function updateFantiumNFTAddress(address _fantiumNFTContractAddress)
        public
        onlyPlatformManager
    {
        fantiumNFTContractAddress = _fantiumNFTContractAddress;
        fantiumNFTContract = IFantiumNFT(_fantiumNFTContractAddress);
        emit FantiumNFTContractUpdated(_fantiumNFTContractAddress);
    }
}
