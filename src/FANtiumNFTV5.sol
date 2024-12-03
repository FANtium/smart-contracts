// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.28;

import { ContextUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {
    ERC721Upgradeable,
    IERC165Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import { StringsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ECDSAUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import { DefaultOperatorFiltererUpgradeable } from
    "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import {
    IFANtiumNFT,
    Collection,
    CreateCollection,
    UpdateCollection,
    CollectionErrorReason
} from "src/interfaces/IFANtiumNFT.sol";
import { IFANtiumUserManager } from "src/interfaces/IFANtiumUserManager.sol";
import { TokenVersionUtil } from "src/utils/TokenVersionUtil.sol";
import { FANtiumBaseUpgradable } from "src/FANtiumBaseUpgradable.sol";

/**
 * @title FANtium ERC721 contract V5.
 * @author Mathieu Bour - FANtium AG, based on previous work by MTX studio AG.
 */
contract FANtiumNFTV5 is FANtiumBaseUpgradable, ERC721Upgradeable, DefaultOperatorFiltererUpgradeable, IFANtiumNFT {
    using StringsUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    // ========================================================================
    // Constants
    // ========================================================================
    string private constant NAME = "FANtium";
    string private constant SYMBOL = "FAN";

    uint256 private constant ONE_MILLION = 1_000_000;
    bytes4 private constant INTERFACE_ID_ERC2981_OVERRIDE = 0xbb3bafd6;

    // Roles
    // ========================================================================
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    // ========================================================================
    // State variables
    // ========================================================================
    mapping(uint256 => Collection) private _collections;
    string public baseURI;
    mapping(uint256 => mapping(address => uint256)) private UNUSED_collectionIdToAllowList;
    mapping(address => bool) private UNUSED_kycedAddresses;
    uint256 public nextCollectionId;
    address public erc20PaymentToken;
    address public claimContract;
    address public fantiumUserManager;
    address public trustedForwarder;

    // ========================================================================
    // UUPS upgradeable pattern
    // ========================================================================
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        // _disableInitializers(); // TODO: uncomment when we are on v6
    }

    /**
     * @notice Initializes contract.
     * @param _tokenName Name of token.
     * @param _tokenSymbol Token symbol.
     * max(uint248) to avoid overflow when adding to it.
     */
    function initialize(
        address _defaultAdmin,
        string memory _tokenName,
        string memory _tokenSymbol
    )
        public
        initializer
    {
        __ERC721_init(_tokenName, _tokenSymbol);
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __DefaultOperatorFilterer_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        nextCollectionId = 1;
    }

    function version() public pure override returns (string memory) {
        return "5.0.0";
    }

    // ========================================================================
    // Setters
    // ========================================================================
    function setClaimContract(address _claimContract) external onlyManagerOrAdmin {
        claimContract = _claimContract;
    }

    function setUserManager(address _userManager) external onlyManagerOrAdmin {
        fantiumUserManager = _userManager;
    }

    // ========================================================================
    // Interface
    // ========================================================================
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165Upgradeable, AccessControlUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return interfaceId == INTERFACE_ID_ERC2981_OVERRIDE || super.supportsInterface(interfaceId);
    }

    // ========================================================================
    // Modifiers
    // ========================================================================
    modifier onlyAthlete(uint256 collectionId) {
        if (
            _msgSender() != _collections[collectionId].athleteAddress && !hasRole(MANAGER_ROLE, msg.sender)
                && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
        ) {
            revert AthleteOnly(collectionId, msg.sender, _collections[collectionId].athleteAddress);
        }
        _;
    }

    modifier onlyValidCollectionId(uint256 _collectionId) {
        if (!_collections[_collectionId].exists) {
            revert InvalidCollectionId(_collectionId);
        }
        _;
    }

    modifier onlyValidTokenId(uint256 _tokenId) {
        if (!_exists(_tokenId)) {
            revert InvalidTokenId(_tokenId);
        }
        _;
    }

    // ========================================================================
    // ERC2771: logic handled by FANtiumBaseUpgradable
    // ========================================================================
    function isTrustedForwarder(address forwarder) public view override returns (bool) {
        return FANtiumBaseUpgradable.isTrustedForwarder(forwarder);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, FANtiumBaseUpgradable)
        returns (address sender)
    {
        return FANtiumBaseUpgradable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, FANtiumBaseUpgradable)
        returns (bytes calldata)
    {
        return FANtiumBaseUpgradable._msgData();
    }

    // ========================================================================
    // Minting
    // ========================================================================
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
    )
        public
        view
        onlyValidCollectionId(collectionId)
        returns (bool useAllowList)
    {
        if (!IFANtiumUserManager(fantiumUserManager).isKYCed(_msgSender())) {
            revert AccountNotKYCed(recipient);
        }

        Collection memory collection = _collections[collectionId];

        if (collection.launchTimestamp > block.timestamp) {
            revert CollectionNotLaunched(collectionId);
        }

        if (!collection.isMintable) {
            revert CollectionNotMintable(collectionId);
        }

        // If the collection is paused, we need to check if the recipient is on the allowlist and has enough allocation
        if (collection.isPaused) {
            useAllowList = true;
            bool isAllowListed = IFANtiumUserManager(fantiumUserManager).allowlist(recipient, collectionId) >= quantity;
            if (!isAllowListed) {
                revert CollectionPaused(collectionId);
            }
        }

        return useAllowList;
    }

    /**
     * @dev Internal function to mint tokens of a collection.
     * @param collectionId Collection ID.
     * @param quantity Amount of tokens to mint.
     * @param recipient Recipient of the mint.
     * @return lastTokenId The ID of the last minted token. Token range is [lastTokenId - quantity + 1, lastTokenId].
     */
    function _mintTo(
        uint256 collectionId,
        uint24 quantity,
        uint256 amount,
        address recipient
    )
        internal
        whenNotPaused
        returns (uint256 lastTokenId)
    {
        Collection memory collection = _collections[collectionId];
        uint256 tokenId = (collectionId * ONE_MILLION) + collection.invocations;

        // CHECKS (in the mintable function)
        bool useAllowList = mintable(collectionId, quantity, recipient);

        // EFFECTS
        _collections[collectionId].invocations += quantity;
        if (useAllowList) {
            IFANtiumUserManager(fantiumUserManager).decreaseAllowList(recipient, collectionId, quantity);
        }

        // INTERACTIONS
        // Send funds to the treasury and athlete account.
        _splitFunds(amount, collectionId, _msgSender());

        for (uint256 i = 0; i < quantity; i++) {
            _mint(recipient, tokenId + i);
        }

        lastTokenId = tokenId + quantity - 1;
    }

    /**
     * @notice Purchase NFTs from the sale.
     * @param collectionId The collection ID to purchase from.
     * @param quantity The quantity of NFTs to purchase.
     * @param recipient The recipient of the NFTs.
     */
    function mintTo(uint256 collectionId, uint24 quantity, address recipient) public whenNotPaused returns (uint256) {
        Collection memory collection = _collections[collectionId];
        uint256 amount = collection.price * quantity;
        return _mintTo(collectionId, quantity, amount, recipient);
    }

    /**
     * @notice Purchase NFTs from the sale with a custom price, checked
     * @param collectionId The collection ID to purchase from.
     * @param quantity The quantity of NFTs to purchase.
     * @param recipient The recipient of the NFTs.
     * @param amount The amount of tokens to purchase the NFTs with.
     * @param signature The signature of the purchase request.
     */
    function mintTo(
        uint256 collectionId,
        uint24 quantity,
        address recipient,
        uint256 amount,
        bytes memory signature
    )
        public
        whenNotPaused
        returns (uint256)
    {
        bytes32 hash =
            keccak256(abi.encode(_msgSender(), collectionId, quantity, amount, recipient)).toEthSignedMessageHash();
        if (!hasRole(SIGNER_ROLE, hash.recover(signature))) {
            revert InvalidSignature();
        }

        return _mintTo(collectionId, quantity, amount, recipient);
    }

    /**
     * @notice View function that returns appropriate revenue splits between
     * different FANtium, athlete given a sale price of `_price` on collection `_collectionId`.
     * This always returns two revenue amounts and two addresses, but if a
     * revenue is zero for athlete, the corresponding
     * address returned will also be null (for gas optimization).
     * Does not account for refund if user overpays for a token
     * @param collectionId collection ID to be queried.
     * @param price Sale price of token.
     * @return fantiumRevenue amount of revenue to be sent to FANtium
     * @return fantiumAddress address to send FANtium revenue to
     * @return athleteRevenue amount of revenue to be sent to athlete
     * @return athleteAddress address to send athlete revenue to. Will be null
     * if no revenue is due to athlete (gas optimization).
     * @dev this always returns 2 addresses and 2 revenues, but if the
     * revenue is zero, the corresponding address will be address(0). It is up
     * to the contract performing the revenue split to handle this
     * appropriately.
     */

    /**
     * @dev Returns the primary revenue splits for a given collection and price.
     * @param collectionId collection ID to be queried.
     * @param price Sale price of token.
     * @return fantiumRevenue amount of revenue to be sent to FANtium
     * @return fantiumAddress address to send FANtium revenue to
     * @return athleteRevenue amount of revenue to be sent to athlete
     * @return athleteAddress address to send athlete revenue to
     */
    function getPrimaryRevenueSplits(
        uint256 collectionId,
        uint256 price
    )
        public
        view
        returns (
            uint256 fantiumRevenue,
            address payable fantiumAddress,
            uint256 athleteRevenue,
            address payable athleteAddress
        )
    {
        // get athlete address & revenue from collection
        Collection memory collection = _collections[collectionId];

        // calculate revenues
        athleteRevenue = (price * collection.athletePrimarySalesBPS) / 10_000;
        fantiumRevenue = price - athleteRevenue;

        // set addresses from storage
        fantiumAddress = collection.fantiumSalesAddress;
        athleteAddress = collection.athleteAddress;
    }

    /**
     * @dev splits funds between sender (if refund),
     * FANtium, and athlete for a token purchased on
     * collection `_collectionId`.
     */
    function _splitFunds(uint256 _price, uint256 _collectionId, address _sender) internal {
        // split funds between FANtium and athlete
        (uint256 fantiumRevenue_, address fantiumAddress_, uint256 athleteRevenue_, address athleteAddress_) =
            getPrimaryRevenueSplits(_collectionId, _price);

        // FANtium payment
        if (fantiumRevenue_ > 0) {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(erc20PaymentToken), _sender, fantiumAddress_, fantiumRevenue_
            );
        }

        // athlete payment
        if (athleteRevenue_ > 0) {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(erc20PaymentToken), _sender, athleteAddress_, athleteRevenue_
            );
        }
    }

    // ========================================================================
    // ERC721 overrides
    // ========================================================================
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        whenNotPaused
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        whenNotPaused
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        whenNotPaused
        onlyAllowedOperator(from)
    {
        super.transferFrom(from, to, tokenId);
    }

    function approve(
        address operator,
        uint256 tokenId
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        whenNotPaused
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    )
        public
        override(ERC721Upgradeable, IERC721Upgradeable)
        whenNotPaused
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function setBaseURI(string memory _baseURI) external whenNotPaused onlyManagerOrAdmin {
        baseURI = _baseURI;
    }

    /**
     * @notice Gets token URI for token ID `_tokenId`.
     * @dev token URIs are the concatenation of the collection base URI and the
     * token ID.
     */
    function tokenURI(uint256 _tokenId) public view override onlyValidTokenId(_tokenId) returns (string memory) {
        return string(bytes.concat(bytes(baseURI), bytes(_tokenId.toString())));
    }

    // ========================================================================
    // Collections
    // ========================================================================
    function collections(uint256 _collectionId) external view returns (Collection memory) {
        return _collections[_collectionId];
    }

    function getCollectionAthleteAddress(uint256 _collectionId) external view returns (address) {
        return _collections[_collectionId].athleteAddress;
    }

    function getEarningsShares1e7(uint256 _collectionId) external view returns (uint256, uint256) {
        return (_collections[_collectionId].tournamentEarningShare1e7, _collections[_collectionId].otherEarningShare1e7);
    }

    function getCollectionExists(uint256 _collectionId) external view returns (bool) {
        return _collections[_collectionId].exists;
    }

    function getMintedTokensOfCollection(uint256 _collectionId) external view returns (uint24) {
        return _collections[_collectionId].invocations;
    }

    /**
     * @notice Creates a new collection.
     * @dev Restricted to platform manager.
     */
    function createCollection(CreateCollection memory data)
        external
        whenNotPaused
        onlyManagerOrAdmin
        returns (uint256)
    {
        // Validate the data
        if (data.athleteSecondarySalesBPS + data.fantiumSecondarySalesBPS > 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_BPS_SUM);
        }

        if (data.maxInvocations >= 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_MAX_INVOCATIONS);
        }

        if (data.athletePrimarySalesBPS > 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_PRIMARY_SALES_BPS);
        }

        if (nextCollectionId >= 1_000_000) {
            revert InvalidCollection(CollectionErrorReason.MAX_COLLECTIONS_REACHED);
        }

        if (data.tournamentEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_TOURNAMENT_EARNING_SHARE);
        }

        if (data.otherEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_OTHER_EARNING_SHARE);
        }

        if (data.athleteAddress == address(0)) {
            revert InvalidCollection(CollectionErrorReason.INVALID_ATHLETE_ADDRESS);
        }

        if (data.fantiumSalesAddress == address(0)) {
            revert InvalidCollection(CollectionErrorReason.INVALID_FANTIUM_SALES_ADDRESS);
        }

        uint256 collectionId = nextCollectionId++;
        Collection memory collection = Collection({
            athleteAddress: data.athleteAddress,
            athletePrimarySalesBPS: data.athletePrimarySalesBPS,
            athleteSecondarySalesBPS: data.athleteSecondarySalesBPS,
            exists: true,
            fantiumSalesAddress: data.fantiumSalesAddress,
            fantiumSecondarySalesBPS: data.fantiumSecondarySalesBPS,
            invocations: 0,
            isMintable: false,
            isPaused: true,
            launchTimestamp: data.launchTimestamp,
            maxInvocations: data.maxInvocations,
            otherEarningShare1e7: data.otherEarningShare1e7,
            price: data.price,
            tournamentEarningShare1e7: data.tournamentEarningShare1e7
        });
        _collections[collectionId] = collection;

        return collectionId;
    }

    function updateCollection(
        uint256 collectionId,
        UpdateCollection memory data
    )
        external
        onlyValidCollectionId(collectionId)
        whenNotPaused
        onlyManagerOrAdmin
    {
        if (data.price == 0) {
            revert InvalidCollection(CollectionErrorReason.INVALID_PRICE);
        }

        if (data.tournamentEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_TOURNAMENT_EARNING_SHARE);
        }

        if (data.otherEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_OTHER_EARNING_SHARE);
        }

        if (data.maxInvocations >= 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_MAX_INVOCATIONS);
        }

        if (data.fantiumSalesAddress == address(0)) {
            revert InvalidCollection(CollectionErrorReason.INVALID_FANTIUM_SALES_ADDRESS);
        }

        if (data.athleteSecondarySalesBPS + data.fantiumSecondarySalesBPS > 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_SECONDARY_SALES_BPS);
        }

        Collection memory existing = _collections[collectionId];
        existing.fantiumSecondarySalesBPS = data.fantiumSecondarySalesBPS;
        existing.maxInvocations = data.maxInvocations;
        existing.price = data.price;
        existing.tournamentEarningShare1e7 = data.tournamentEarningShare1e7;
        existing.otherEarningShare1e7 = data.otherEarningShare1e7;
        _collections[collectionId] = existing;
    }

    /**
     * @notice Toggles isMintingPaused state of collection `_collectionId`.
     */
    function toggleCollectionPaused(uint256 collectionId)
        external
        onlyValidCollectionId(collectionId)
        onlyAthlete(collectionId)
    {
        _collections[collectionId].isPaused = !_collections[collectionId].isPaused;
    }

    /**
     * @notice Toggles isMintingPaused state of collection `_collectionId`.
     */
    function toggleCollectionMintable(uint256 collectionId)
        external
        onlyValidCollectionId(collectionId)
        onlyAthlete(collectionId)
    {
        _collections[collectionId].isMintable = !_collections[collectionId].isMintable;
    }

    function updateCollectionAthleteAddress(
        uint256 collectionId,
        address payable athleteAddress
    )
        external
        onlyValidCollectionId(collectionId)
        onlyManagerOrAdmin
    {
        if (athleteAddress == address(0)) {
            revert InvalidCollection(CollectionErrorReason.INVALID_ATHLETE_ADDRESS);
        }

        _collections[collectionId].athleteAddress = athleteAddress;
    }

    /**
     * @notice Updates athlete primary market royalties for collection
     * `_collectionId` to be `_primaryMarketRoyalty` percent.
     * This DOES NOT include the primary market royalty percentages collected
     * by FANtium; this is only the total percentage of royalties that will
     * be split to athlete.
     * @param collectionId collection ID.
     * @param primaryMarketRoyalty Percent of primary sales revenue that will
     * be sent to the athlete. This must be less than
     * or equal to 100 percent.
     */
    function updateCollectionAthletePrimaryMarketRoyaltyBPS(
        uint256 collectionId,
        uint256 primaryMarketRoyalty
    )
        external
        onlyValidCollectionId(collectionId)
        onlyManagerOrAdmin
    {
        if (primaryMarketRoyalty > 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_PRIMARY_SALES_BPS);
        }

        _collections[collectionId].athletePrimarySalesBPS = primaryMarketRoyalty;
    }

    /**
     * @notice Updates athlete secondary market royalties for collection
     * `_collectionId` to be `_secondMarketRoyalty` percent.
     * This DOES NOT include the secondary market royalty percentages collected
     * by FANtium; this is only the total percentage of royalties that will
     * be split to athlete.
     * @param collectionId collection ID.
     * @param secondMarketRoyalty Percent of secondary sales revenue that will
     * be sent to the athlete. This must be less than
     * or equal to 95 percent.
     */
    function updateCollectionAthleteSecondaryMarketRoyaltyBPS(
        uint256 collectionId,
        uint256 secondMarketRoyalty
    )
        external
        onlyValidCollectionId(collectionId)
        onlyManagerOrAdmin
    {
        if (secondMarketRoyalty + _collections[collectionId].fantiumSecondarySalesBPS > 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_SECONDARY_SALES_BPS);
        }

        _collections[collectionId].athleteSecondarySalesBPS = secondMarketRoyalty;
    }

    /**
     * @notice Updates the launch timestamp of collection `_collectionId` to be
     * `_launchTimestamp`.
     */
    function updateCollectionLaunchTimestamp(
        uint256 _collectionId,
        uint256 _launchTimestamp
    )
        external
        onlyValidCollectionId(_collectionId)
        onlyManagerOrAdmin
    {
        _collections[_collectionId].launchTimestamp = _launchTimestamp;
    }

    /*///////////////////////////////////////////////////////////////
                        PLATFORM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setERC20PaymentToken(address _erc20PaymentToken) external onlyManagerOrAdmin {
        erc20PaymentToken = _erc20PaymentToken;
    }

    // ========================================================================
    // Claiming functions
    // ========================================================================
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
        if (ownerOf(newTokenId) == tokenOwner) {
            return true;
        } else {
            return false;
        }
    }

    // ========================================================================
    // Royalty functions
    // ========================================================================
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
    function getRoyalties(uint256 _tokenId)
        external
        view
        onlyValidTokenId(_tokenId)
        returns (address payable[] memory recipients, uint256[] memory bps)
    {
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
}
