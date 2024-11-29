// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {DefaultOperatorFiltererUpgradeable} from "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import "./interfaces/IFANtiumNFT.sol";
import "./utils/TokenVersionUtil.sol";
import "./interfaces/IFantiumUserManager.sol";
import "./utils/ERC2771ContextUpgradeable.sol";

/**
 * @title FANtium ERC721 contract V5.
 * @author Mathieu Bour - FANtium AG, based on previous work by MTX studio AG.
 */
contract FANtiumNFTV5 is
    Initializable,
    ERC721Upgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    DefaultOperatorFiltererUpgradeable,
    PausableUpgradeable,
    IFANtiumNFT
{
    using StringsUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    // ========================================================================
    // Constants
    // ========================================================================
    uint256 public constant ONE_MILLION = 1_000_000;
    bytes4 private constant _INTERFACE_ID_ERC2981_OVERRIDE = 0xbb3bafd6;

    // Roles
    // ========================================================================
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE = keccak256("PLATFORM_MANAGER_ROLE");
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    // Fields
    // ========================================================================
    bytes32 public constant FIELD_FANTIUM_SECONDARY_MARKET_ROYALTY_BPS = "fantium secondary royalty BPS";
    bytes32 public constant FIELD_FANTIUM_PRIMARY_ADDRESS = "fantium primary sale address";
    bytes32 public constant FIELD_FANTIUM_SECONDARY_ADDRESS = "fantium secondary sale address";
    bytes32 public constant FIELD_COLLECTION_CREATED = "created";
    bytes32 public constant FIELD_COLLECTION_NAME = "name";
    bytes32 public constant FIELD_COLLECTION_ATHLETE_NAME = "name";
    bytes32 public constant FIELD_COLLECTION_ATHLETE_ADDRESS = "athlete address";
    bytes32 public constant FIELD_COLLECTION_PAUSED = "isMintingPaused";
    bytes32 public constant FIELD_COLLECTION_PRICE = "price";
    bytes32 public constant FIELD_COLLECTION_MAX_INVOCATIONS = "max invocations";
    bytes32 public constant FIELD_COLLECTION_PRIMARY_MARKET_ROYALTY_PERCENTAGE = "collection primary sale %";
    bytes32 public constant FIELD_COLLECTION_SECONDARY_MARKET_ROYALTY_PERCENTAGE = "collection secondary sale %";
    bytes32 public constant FIELD_COLLECTION_BASE_URI = "collection base uri";
    bytes32 public constant FIELD_COLLECTION_TIER = "collection tier";
    bytes32 public constant FILED_FANTIUM_BASE_URI = "fantium base uri";
    bytes32 public constant FIELD_FANTIUM_MINTER_ADDRESS = "fantium minter address";
    bytes32 public constant FIELD_COLLECTION_ACTIVATED = "isActivated";
    bytes32 public constant FIELD_COLLECTION_LAUNCH_TIMESTAMP = "launch timestamp";

    // ========================================================================
    // State variables
    // ========================================================================
    mapping(uint256 => Collection) private _collections;
    string public baseURI;
    mapping(uint256 => mapping(address => uint256)) public UNUSED_collectionIdToAllowList;
    mapping(address => bool) public UNUSED_kycedAddresses;
    uint256 public nextCollectionId;
    address public erc20PaymentToken;
    address public claimContract;
    address public fantiumUserManager;
    address public trustedForwarder;

    // ========================================================================
    // Events
    // ========================================================================
    event Mint(address indexed _to, uint256 indexed _tokenId);
    event CollectionUpdated(uint256 indexed _collectionId, bytes32 indexed _update);
    event PlatformUpdated(bytes32 indexed _field);

    // ========================================================================
    // Errors
    // ========================================================================
    error AccountNotKYCed(address recipient);
    error CollectionDoesNotExist(uint256 collectionId);
    error CollectionNotLaunched(uint256 collectionId);
    error CollectionNotMintable(uint256 collectionId);
    error CollectionPaused(uint256 collectionId);
    error InvalidSignature();

    // ========================================================================
    // Interface
    // ========================================================================

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165Upgradeable, AccessControlUpgradeable, ERC721Upgradeable) returns (bool) {
        return interfaceId == _INTERFACE_ID_ERC2981_OVERRIDE || super.supportsInterface(interfaceId);
    }

    // ========================================================================
    // Modifiers
    // ========================================================================
    modifier onlyReady() {
        require(fantiumUserManager != address(0), "UserManager not set");
        _;
    }

    modifier onlyAthlete(uint256 _collectionId) {
        require(
            _msgSender() == _collections[_collectionId].athleteAddress || hasRole(PLATFORM_MANAGER_ROLE, msg.sender),
            "Only athlete"
        );
        _;
    }

    modifier onlyValidCollectionId(uint256 _collectionId) {
        require(_collections[_collectionId].exists == true, "Invalid collectionId");
        _;
    }

    modifier onlyValidTokenId(uint256 _tokenId) {
        require(_exists(_tokenId), "Invalid tokenId");
        _;
    }

    modifier onlyPlatformManager() {
        require(hasRole(PLATFORM_MANAGER_ROLE, msg.sender), "Only PlatformManager");
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
        string memory _tokenName,
        string memory _tokenSymbol,
        address _defaultAdmin
    ) public initializer {
        __ERC721_init(_tokenName, _tokenSymbol);
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __DefaultOperatorFilterer_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(UPGRADER_ROLE, _defaultAdmin);
        nextCollectionId = 1;
    }

    // ========================================================================
    // UUPS upgradeable functions
    // ========================================================================
    /// @custom:oz-upgrades-unsafe-allow constructor
    // ERC2771ContextUpgradeable(forwarder)
    // add: (address forwarder)
    constructor() {
        _disableInitializers();
    }

    /// @notice upgrade authorization logic
    /// @dev required by the OZ UUPS module
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
                                 MINTING
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Checks if a mint is possible for a collection
     * @param collectionId Collection ID.
     * @param quantity Amount of tokens to mint.
     * @param recipient Recipient of the mint.
     */
    function mintable(
        uint256 collectionId,
        uint24 quantity,
        address recipient
    ) public view returns (bool useAllowList) {
        if (!IFantiumUserManager(fantiumUserManager).isAddressKYCed(_msgSender())) {
            revert AccountNotKYCed(recipient);
        }

        Collection memory collection = _collections[collectionId];

        if (!collection.exists) {
            revert CollectionDoesNotExist(collectionId);
        }

        if (collection.launchTimestamp > block.timestamp) {
            revert CollectionNotLaunched(collectionId);
        }

        if (!collection.isMintable) {
            revert CollectionNotMintable(collectionId);
        }

        // If the collection is paused, we need to check if the recipient is on the allowlist and has enough allocation
        if (collection.isPaused) {
            useAllowList = true;
            bool isAllowListed = IFantiumUserManager(fantiumUserManager).hasAllowlist(
                address(this),
                collectionId,
                recipient
            ) >= quantity;
            if (!isAllowListed) {
                revert CollectionPaused(collectionId);
            }
        }

        return useAllowList;
    }

    /**
     * @dev internal function to mint tokens of a collection - does not reduce allowlist allocation
     * @param collectionId Collection ID.
     * @param quantity Amount of tokens to mint.
     * @param recipient Recipient of the mint.
     */
    function _mintTo(uint256 collectionId, uint24 quantity, uint256 amount, address recipient) internal whenNotPaused {
        Collection memory collection = _collections[collectionId];
        uint256 tokenId = (collectionId * ONE_MILLION) + collection.invocations;

        // CHECKS (in the mintable function)
        bool useAllowList = mintable(collectionId, quantity, recipient);

        // EFFECTS
        _collections[collectionId].invocations += quantity;
        if (useAllowList) {
            IFantiumUserManager(fantiumUserManager).reduceAllowListAllocation(
                collectionId,
                address(this),
                recipient,
                quantity
            );
        }

        // INTERACTIONS
        // Send funds to the treasury and athlete account.
        _splitFunds(amount, collectionId, _msgSender());

        for (uint256 i = 0; i < quantity; i++) {
            _mint(recipient, tokenId + i);
            emit Mint(recipient, tokenId + i);
        }
    }

    /**
     * @notice Purchase NFTs from the sale.
     * @param collectionId The collection ID to purchase from.
     * @param quantity The quantity of NFTs to purchase.
     * @param recipient The recipient of the NFTs.
     */
    function mintTo(uint256 collectionId, uint24 quantity, address recipient) public whenNotPaused {
        Collection memory collection = _collections[collectionId];
        uint256 amount = collection.price * quantity;
        _mintTo(collectionId, quantity, amount, recipient);
    }

    /**
     * @notice Purchase NFTs from the sale with a custom price, checked
     * @param collectionId The collection ID to purchase from.
     * @param quantity The quantity of NFTs to purchase.
     * @param amount The amount of tokens to purchase the NFTs with.
     * @param recipient The recipient of the NFTs.
     * @param signature The signature of the purchase request.
     */
    function mintTo(
        uint256 collectionId,
        uint24 quantity,
        uint256 amount,
        address recipient,
        bytes memory signature
    ) public whenNotPaused {
        bytes32 hash = keccak256(abi.encode(_msgSender(), collectionId, quantity, amount, recipient))
            .toEthSignedMessageHash();
        if (!hasRole(SIGNER_ROLE, hash.recover(signature))) {
            revert InvalidSignature();
        }

        _mintTo(collectionId, quantity, amount, recipient);
    }

    /**
     * @notice View function that returns appropriate revenue splits between
     * different FANtium, athlete given a sale price of `_price` on collection `_collectionId`.
     * This always returns two revenue amounts and two addresses, but if a
     * revenue is zero for athlete, the corresponding
     * address returned will also be null (for gas optimization).
     * Does not account for refund if user overpays for a token
     * @param _collectionId collection ID to be queried.
     * @param _price Sale price of token.
     * @return fantiumRevenue_ amount of revenue to be sent to FANtium
     * @return fantiumAddress_ address to send FANtium revenue to
     * @return athleteRevenue_ amount of revenue to be sent to athlete
     * @return athleteAddress_ address to send athlete revenue to. Will be null
     * if no revenue is due to athlete (gas optimization).
     * @dev this always returns 2 addresses and 2 revenues, but if the
     * revenue is zero, the corresponding address will be address(0). It is up
     * to the contract performing the revenue split to handle this
     * appropriately.
     */
    function getPrimaryRevenueSplits(
        uint256 _collectionId,
        uint256 _price
    )
        public
        view
        returns (
            uint256 fantiumRevenue_,
            address payable fantiumAddress_,
            uint256 athleteRevenue_,
            address payable athleteAddress_
        )
    {
        // get athlete address & revenue from collection
        Collection memory collection = _collections[_collectionId];

        // calculate revenues
        athleteRevenue_ = (_price * collection.athletePrimarySalesBPS) / 10000;

        fantiumRevenue_ = _price - athleteRevenue_;

        // set addresses from storage
        fantiumAddress_ = collection.fantiumSalesAddress;
        if (athleteRevenue_ > 0) {
            athleteAddress_ = collection.athleteAddress;
        }
    }

    /**
     * @dev splits funds between sender (if refund),
     * FANtium, and athlete for a token purchased on
     * collection `_collectionId`.
     */
    function _splitFunds(uint256 _price, uint256 _collectionId, address _sender) internal {
        // split funds between FANtium and athlete
        (
            uint256 fantiumRevenue_,
            address fantiumAddress_,
            uint256 athleteRevenue_,
            address athleteAddress_
        ) = getPrimaryRevenueSplits(_collectionId, _price);

        // FANtium payment
        if (fantiumRevenue_ > 0) {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(erc20PaymentToken),
                _sender,
                fantiumAddress_,
                fantiumRevenue_
            );
        }

        // athlete payment
        if (athleteRevenue_ > 0) {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(erc20PaymentToken),
                _sender,
                athleteAddress_,
                athleteRevenue_
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 TOKEN
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets token URI for token ID `_tokenId`.
     * @dev token URIs are the concatenation of the collection base URI and the
     * token ID.
     */
    function tokenURI(uint256 _tokenId) public view override onlyValidTokenId(_tokenId) returns (string memory) {
        return string(bytes.concat(bytes(baseURI), bytes(_tokenId.toString())));
    }

    /*//////////////////////////////////////////////////////////////
                        COLLECTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function collections(uint256 _collectionId) external view returns (Collection memory) {
        return _collections[_collectionId];
    }

    /**
     * @notice Adds new collection.
     * @param _athleteAddress Address of the athlete.
     * @param _athletePrimarySalesBPS Primary sales percentage of the athlete.
     * @param _athleteSecondarySalesBPS Secondary sales percentage of the athlete.
     * @param _maxInvocations Maximum number of invocations.
     * @param _price Price of the token.
     * @param _tournamentEarningShare1e7 Tournament earning share.
     * @param _otherEarningShare1e7 Tournament earning share.
     * @param _launchTimestamp Launch timestamp.
     */
    function addCollection(
        address payable _athleteAddress,
        uint256 _athletePrimarySalesBPS,
        uint256 _athleteSecondarySalesBPS,
        uint256 _maxInvocations,
        uint256 _price,
        uint256 _launchTimestamp,
        address payable _fantiumSalesAddress,
        uint256 _fantiumSecondarySalesBPS,
        uint256 _tournamentEarningShare1e7,
        uint256 _otherEarningShare1e7
    ) external whenNotPaused onlyPlatformManager returns (uint256) {
        require(
            _athleteSecondarySalesBPS + _fantiumSecondarySalesBPS <= 10_000,
            "FantiumNFTV3: secondary sales BPS must be less than 10,000"
        );
        require(_maxInvocations < 10_000, "FantiumNFTV3: max invocations must be less than 10,000");
        require(_athletePrimarySalesBPS <= 10_000, "FantiumNFTV3: athletePrimarySalesBPS must be less than 10,000");
        require(nextCollectionId < 1_000_000, "FantiumNFTV3: max collections reached");
        require(
            _tournamentEarningShare1e7 <= 1e7 && _otherEarningShare1e7 <= 1e7,
            "FantiumNFTV3: token share must be smaller 1e7"
        );

        require(
            _athleteAddress != address(0) && _fantiumSalesAddress != address(0),
            "FantiumNFTV3: addresses cannot be 0"
        );

        uint256 collectionId = nextCollectionId;

        _collections[collectionId].athleteAddress = _athleteAddress;
        _collections[collectionId].athletePrimarySalesBPS = _athletePrimarySalesBPS;
        _collections[collectionId].athleteSecondarySalesBPS = _athleteSecondarySalesBPS;
        _collections[collectionId].maxInvocations = _maxInvocations;
        _collections[collectionId].price = _price;

        _collections[collectionId].launchTimestamp = _launchTimestamp;

        _collections[collectionId].invocations = 0;
        _collections[collectionId].exists = true;
        _collections[collectionId].isMintable = false;
        _collections[collectionId].isPaused = true;

        _collections[collectionId].fantiumSalesAddress = _fantiumSalesAddress;
        _collections[collectionId].fantiumSecondarySalesBPS = _fantiumSecondarySalesBPS;

        _collections[collectionId].tournamentEarningShare1e7 = _tournamentEarningShare1e7;
        _collections[collectionId].otherEarningShare1e7 = _otherEarningShare1e7;

        nextCollectionId = collectionId + 1;
        emit CollectionUpdated(collectionId, FIELD_COLLECTION_CREATED);

        return collectionId;
    }

    /**
     * @notice Updates athlete of collection `_collectionId` to `_athleteAddress`.
     */
    function updateCollectionAthleteAddress(
        uint256 _collectionId,
        address payable _athleteAddress
    ) external onlyValidCollectionId(_collectionId) onlyPlatformManager {
        require(_athleteAddress != address(0), "FantiumNFTV3: address cannot be 0");
        _collections[_collectionId].athleteAddress = _athleteAddress;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_ATHLETE_ADDRESS);
    }

    /**
     * @notice Toggles isMintingPaused state of collection `_collectionId`.
     */
    function toggleCollectionPaused(
        uint256 _collectionId
    ) external onlyValidCollectionId(_collectionId) onlyAthlete(_collectionId) {
        _collections[_collectionId].isPaused = !_collections[_collectionId].isPaused;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_PAUSED);
    }

    /**
     * @notice Toggles isMintingPaused state of collection `_collectionId`.
     */
    function toggleCollectionMintable(
        uint256 _collectionId
    ) external onlyValidCollectionId(_collectionId) onlyAthlete(_collectionId) {
        _collections[_collectionId].isMintable = !_collections[_collectionId].isMintable;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_ACTIVATED);
    }

    /**
     * @notice Updates athlete primary market royalties for collection
     * `_collectionId` to be `_primaryMarketRoyalty` percent.
     * This DOES NOT include the primary market royalty percentages collected
     * by FANtium; this is only the total percentage of royalties that will
     * be split to athlete.
     * @param _collectionId collection ID.
     * @param _primaryMarketRoyalty Percent of primary sales revenue that will
     * be sent to the athlete. This must be less than
     * or equal to 100 percent.
     */
    function updateCollectionAthletePrimaryMarketRoyaltyBPS(
        uint256 _collectionId,
        uint256 _primaryMarketRoyalty
    ) external onlyValidCollectionId(_collectionId) onlyPlatformManager {
        require(_primaryMarketRoyalty <= 10000, "Max of 100%");
        _collections[_collectionId].athletePrimarySalesBPS = _primaryMarketRoyalty;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_PRIMARY_MARKET_ROYALTY_PERCENTAGE);
    }

    /**
     * @notice Updates athlete secondary market royalties for collection
     * `_collectionId` to be `_secondMarketRoyalty` percent.
     * This DOES NOT include the secondary market royalty percentages collected
     * by FANtium; this is only the total percentage of royalties that will
     * be split to athlete.
     * @param _collectionId collection ID.
     * @param _secondMarketRoyalty Percent of secondary sales revenue that will
     * be sent to the athlete. This must be less than
     * or equal to 95 percent.
     */
    function updateCollectionAthleteSecondaryMarketRoyaltyBPS(
        uint256 _collectionId,
        uint256 _secondMarketRoyalty
    ) external onlyValidCollectionId(_collectionId) onlyPlatformManager {
        require(
            _secondMarketRoyalty + _collections[_collectionId].fantiumSecondarySalesBPS <= 10000,
            "FantiumClaimingV1: secondary sales BPS must be less than 10,000"
        );
        _collections[_collectionId].athleteSecondarySalesBPS = _secondMarketRoyalty;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_SECONDARY_MARKET_ROYALTY_PERCENTAGE);
    }

    /**
     * @notice Update Collection tier for collection `_collectionId` to be `_tierName`.
     */
    function updateCollectionSales(
        uint256 _collectionId,
        uint256 _maxInvocations,
        uint256 _price,
        uint256 _tournamentEarningShare1e7,
        uint256 _otherEarningShare1e7,
        address payable _fantiumSalesAddress,
        uint256 _fantiumSecondarySalesBPS
    ) external onlyValidCollectionId(_collectionId) onlyPlatformManager {
        // require to have either other token share or tournament token share set to > 0
        require(
            _price > 0 && (_tournamentEarningShare1e7 > 0 || _otherEarningShare1e7 > 0),
            "FantiumNFTV3: all parameters must be greater than 0"
        );
        require(_maxInvocations < 10_000, "FantiumNFTV3: max invocations must be less than 10,000");
        require(nextCollectionId < 1_000_000, "FantiumNFTV3: max collections reached");
        require(
            _tournamentEarningShare1e7 <= 1e7 && _otherEarningShare1e7 <= 1e7,
            "FantiumNFTV3: token share must be less than 1e7"
        );

        require(
            _maxInvocations >= _collections[_collectionId].invocations,
            "FantiumNFTV3: max invocations must be greater than current invocations"
        );

        require(_fantiumSalesAddress != address(0), "FantiumNFTV3: address cannot be 0");

        require(
            _collections[_collectionId].athleteSecondarySalesBPS + _fantiumSecondarySalesBPS <= 10_000,
            "FantiumNFTV3: secondary sales BPS must be less than 10,000"
        );

        _collections[_collectionId].fantiumSalesAddress = _fantiumSalesAddress;
        _collections[_collectionId].fantiumSecondarySalesBPS = _fantiumSecondarySalesBPS;

        _collections[_collectionId].maxInvocations = _maxInvocations;
        _collections[_collectionId].price = _price;

        _collections[_collectionId].tournamentEarningShare1e7 = _tournamentEarningShare1e7;
        _collections[_collectionId].otherEarningShare1e7 = _otherEarningShare1e7;

        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_TIER);
    }

    /**
     * @notice Updates the launch timestamp of collection `_collectionId` to be
     * `_launchTimestamp`.
     */
    function updateCollectionLaunchTimestamp(
        uint256 _collectionId,
        uint256 _launchTimestamp
    ) external onlyValidCollectionId(_collectionId) onlyPlatformManager {
        _collections[_collectionId].launchTimestamp = _launchTimestamp;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_LAUNCH_TIMESTAMP);
    }

    /*///////////////////////////////////////////////////////////////
                        PLATFORM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    //update baseURI only platform manager
    function updateBaseURI(string memory _baseURI) external whenNotPaused onlyPlatformManager {
        baseURI = _baseURI;
        emit PlatformUpdated(FILED_FANTIUM_BASE_URI);
    }

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
                            CLAIMING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice upgrade token version to new version in case of claim event
     */
    function upgradeTokenVersion(uint256 _tokenId) external whenNotPaused onlyValidTokenId(_tokenId) returns (bool) {
        // only claim contract can call this function
        require(claimContract != address(0), "Claim contract address is not set");

        require(claimContract == msg.sender, "Only claim contract can call this function");

        (uint256 _collectionId, uint256 _versionId, uint256 _tokenNr) = TokenVersionUtil.getTokenInfo(_tokenId);
        require(_collections[_collectionId].exists, "Collection does not exist");
        address tokenOwner = ownerOf(_tokenId);

        // burn old token
        _burn(_tokenId);
        _versionId++;

        require(_versionId < 100, "Version id cannot be greater than 99");

        uint256 newTokenId = TokenVersionUtil.createTokenId(_collectionId, _versionId, _tokenNr);
        // mint new token with new version
        _mint(tokenOwner, newTokenId);
        emit Mint(tokenOwner, newTokenId);
        if (ownerOf(newTokenId) == tokenOwner) {
            return true;
        } else {
            return false;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            Address Configs TOKEN
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the erc20 Payment Token
     * @param _paymentTokenAdderss address of ERC20 payment token
     * @param _claimContractAdress address of fantium claim contract
     * @param _userManagerAddress address of fantium userManager contract
     */
    /**
     * @notice Updates the erc20 Payment Token
     * @param _paymentTokenAdderss address of ERC20 payment token
     * @param _claimContractAdress address of fantium claim contract
     * @param _userManagerAddress address of fantium userManager contract
     */
    function updatePlatformAddressesConfigs(
        address _paymentTokenAdderss,
        address _claimContractAdress,
        address _userManagerAddress,
        address _trustedForwarder
    ) external onlyRole(UPGRADER_ROLE) {
        require(
            _paymentTokenAdderss != address(0) &&
                _claimContractAdress != address(0) &&
                _userManagerAddress != address(0) &&
                _trustedForwarder != address(0),
            "FantiumNFTV3: addresses cannot be 0"
        );
        erc20PaymentToken = _paymentTokenAdderss;
        claimContract = _claimContractAdress;
        fantiumUserManager = _userManagerAddress;
        trustedForwarder = _trustedForwarder;
        emit PlatformUpdated("platform address config");
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets royalty Basis Points (BPS) for token ID `_tokenId`.
     * This conforms to the IManifold interface designated in the Royalty
     * Registry's RoyaltyEngineV1.sol contract.
     * ref: https://github.com/manifoldxyz/royalty-registry-solidity
     * @param _tokenId Token ID to be queried.
     * @return recipients Array of royalty payment recipients
     * @return bps Array of Basis Points (BPS) allocated to each recipient,
     * aligned by index.
     * @dev reverts if invalid _tokenId
     * @dev only returns recipients that have a non-zero BPS allocation
     */
    function getRoyalties(
        uint256 _tokenId
    ) external view onlyValidTokenId(_tokenId) returns (address payable[] memory recipients, uint256[] memory bps) {
        // initialize arrays with maximum potential length
        recipients = new address payable[](2);
        bps = new uint256[](2);

        uint256 collectionId = _tokenId / ONE_MILLION;

        Collection storage collection = _collections[collectionId];
        // load values into memory
        uint256 athleteBPS = collection.athleteSecondarySalesBPS;
        uint256 fantiumBPS = collection.fantiumSecondarySalesBPS;
        // populate arrays
        uint256 payeeCount;
        if (athleteBPS > 0) {
            recipients[payeeCount] = collection.athleteAddress;
            bps[payeeCount++] = athleteBPS;
        }
        if (fantiumBPS > 0) {
            recipients[payeeCount] = collection.fantiumSalesAddress;
            bps[payeeCount++] = fantiumBPS;
        }

        return (recipients, bps);
    }

    function getCollectionAthleteAddress(uint256 _collectionId) external view returns (address) {
        return _collections[_collectionId].athleteAddress;
    }

    function getEarningsShares1e7(uint256 _collectionId) external view returns (uint256, uint256) {
        return (
            _collections[_collectionId].tournamentEarningShare1e7,
            _collections[_collectionId].otherEarningShare1e7
        );
    }

    function getCollectionExists(uint256 _collectionId) external view returns (bool) {
        return _collections[_collectionId].exists;
    }

    function getMintedTokensOfCollection(uint256 _collectionId) external view returns (uint24) {
        return _collections[_collectionId].invocations;
    }
}
