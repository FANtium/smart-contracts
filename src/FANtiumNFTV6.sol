// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ECDSAUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {
    ERC721Upgradeable,
    IERC165Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {
    IFANtiumNFT,
    Collection,
    CollectionData,
    CollectionErrorReason,
    MintErrorReason,
    UpgradeErrorReason
} from "src/interfaces/IFANtiumNFT.sol";
import { IFANtiumUserManager } from "src/interfaces/IFANtiumUserManager.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { StringsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import { TokenVersionUtil } from "src/utils/TokenVersionUtil.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title FANtium ERC721 contract V6.
 * @author Mathieu Bour - FANtium AG, based on previous work by MTX studio AG.
 * @custom:oz-upgrades-from FantiumNFTV5
 */
contract FANtiumNFTV6 is
    Initializable,
    ERC721Upgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    IFANtiumNFT
{
    using StringsUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    // ========================================================================
    // Constants
    // ========================================================================
    string private constant NAME = "FANtium";
    string private constant SYMBOL = "FAN";

    uint256 private constant BPS_BASE = 10_000;
    uint256 private constant MAX_COLLECTIONS = 1_000_000;
    uint256 private constant MAX_INVOCATIONS = 10_000;

    // Roles
    // ========================================================================
    bytes32 public constant FORWARDER_ROLE = keccak256("FORWARDER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /**
     * @notice Role for the token upgrader.
     * @dev Used to upgrade the token to a new version.
     */
    bytes32 public constant TOKEN_UPGRADER_ROLE = keccak256("TOKEN_UPGRADER_ROLE");

    // ========================================================================
    // State variables
    // ========================================================================
    /**
     * @notice Mapping of collection IDs to collection data.
     * @custom:oz-renamed-from collections
     */
    mapping(uint256 => Collection) private _collections;

    /**
     * @notice The base URI for the token metadata.
     */
    string public baseURI;

    /**
     * @notice Mapping of collection IDs to allowlist allocations.
     * @dev Deprecated: replaced by the userManager contract.
     * @custom:oz-renamed-from collectionIdToAllowList
     */
    mapping(uint256 => mapping(address => uint256)) private UNUSED_collectionIdToAllowList;

    /**
     * @notice Mapping of addresses that have been KYCed.
     * @dev Deprecated: replaced by the userManager contract.
     * @custom:oz-renamed-from kycedAddresses
     */
    mapping(address => bool) private UNUSED_kycedAddresses;

    /**
     * @notice The next collection ID to be used.
     */
    uint256 public nextCollectionId;

    /**
     * @notice The ERC20 token used for payments, usually a stablecoin.
     */
    address public erc20PaymentToken;

    /**
     * @dev Deprecated: replaced by the TOKEN_UPGRADER_ROLE.
     * @custom:oz-renamed-from claimContract
     */
    address private UNUSED_claimContract;

    /**
     * @dev Use to retrieve user information such as KYC status, IDENT status, and allowlist allocations.
     * @custom:oz-renamed-from fantiumUserManager
     */
    IFANtiumUserManager public userManager;

    /**
     * @dev Deprecated: replaced by the FORWARDER_ROLE.
     * @custom:oz-renamed-from trustedForwarder
     */
    address private UNUSED_trustedForwarder;

    /**
     * @notice Mapping of addresses to their nonce.
     * @dev Used to prevent replay attacks with the mintTo function.
     */
    mapping(address => uint256) public nonces;

    // ========================================================================
    // UUPS upgradeable pattern
    // ========================================================================
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes contract using the UUPS upgradeable pattern.
     * @param admin The admin address.
     */
    function initialize(address admin) public initializer {
        __ERC721_init(NAME, SYMBOL);
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        nextCollectionId = 1;
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
    // Modifiers
    // ========================================================================
    modifier onlyAthleteOrManagerOrAdmin(uint256 collectionId) {
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
    // ERC2771
    // ========================================================================
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return hasRole(FORWARDER_ROLE, forwarder);
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
        return super.supportsInterface(interfaceId);
    }

    // ========================================================================
    // Setters
    // ========================================================================
    /**
     * @notice Sets the base URI for the token metadata.
     * @dev Restricted to manager or admin.
     * @param baseURI_ The new base URI.
     */
    function setBaseURI(string memory baseURI_) external whenNotPaused onlyManagerOrAdmin {
        baseURI = baseURI_;
    }

    /**
     * @notice Sets the user manager.
     * @dev Restricted to manager or admin.
     * @param _userManager The new user manager.
     */
    function setUserManager(IFANtiumUserManager _userManager) external whenNotPaused onlyManagerOrAdmin {
        userManager = _userManager;
    }

    /**
     * @notice Sets the ERC20 payment token.
     * @dev Restricted to manager or admin.
     * @param _erc20PaymentToken The new ERC20 payment token.
     */
    function setERC20PaymentToken(address _erc20PaymentToken) external whenNotPaused onlyManagerOrAdmin {
        erc20PaymentToken = _erc20PaymentToken;
    }

    // ========================================================================
    // ERC721
    // ========================================================================
    /**
     * @dev Returns the base URI for computing {tokenURI}.
     * Necessary to use the default ERC721 tokenURI function from ERC721Upgradeable.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // ========================================================================
    // Collections
    // ========================================================================
    function collections(uint256 _collectionId) external view returns (Collection memory) {
        return _collections[_collectionId];
    }

    function _checkCollectionData(CollectionData memory data) internal view {
        // Validate the data
        if (data.athleteAddress == address(0)) {
            revert InvalidCollection(CollectionErrorReason.INVALID_ATHLETE_ADDRESS);
        }

        if (data.athletePrimarySalesBPS > BPS_BASE) {
            revert InvalidCollection(CollectionErrorReason.INVALID_PRIMARY_SALES_BPS);
        }

        if (data.athleteSecondarySalesBPS + data.fantiumSecondarySalesBPS > BPS_BASE) {
            revert InvalidCollection(CollectionErrorReason.INVALID_BPS_SUM);
        }

        if (data.fantiumSalesAddress == address(0)) {
            revert InvalidCollection(CollectionErrorReason.INVALID_FANTIUM_SALES_ADDRESS);
        }

        if (data.maxInvocations >= MAX_INVOCATIONS) {
            revert InvalidCollection(CollectionErrorReason.INVALID_MAX_INVOCATIONS);
        }

        if (data.otherEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_OTHER_EARNING_SHARE);
        }

        // no check on the price

        if (data.tournamentEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_TOURNAMENT_EARNING_SHARE);
        }

        if (nextCollectionId >= MAX_COLLECTIONS) {
            revert InvalidCollection(CollectionErrorReason.MAX_COLLECTIONS_REACHED);
        }
    }

    /**
     * @notice Creates a new collection.
     * @dev Restricted to manager or admin.
     * @param data The new collection data.
     * @return collectionId The ID of the created collection.
     */
    function createCollection(CollectionData memory data) external whenNotPaused onlyManagerOrAdmin returns (uint256) {
        _checkCollectionData(data);

        uint256 collectionId = nextCollectionId++;
        Collection memory newCollection = Collection({
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
        _collections[collectionId] = newCollection;
        emit CollectionCreated(collectionId, newCollection);

        return collectionId;
    }

    /**
     * @notice Updates a collection.
     * @dev Restricted to manager or admin.
     * @param collectionId The collection ID to update.
     * @param data The new collection data.
     */
    function updateCollection(
        uint256 collectionId,
        CollectionData memory data
    )
        external
        onlyValidCollectionId(collectionId)
        whenNotPaused
        onlyManagerOrAdmin
    {
        _checkCollectionData(data);

        // Ensure the max invocations is not decreased
        Collection memory updatedCollection = _collections[collectionId];
        if (data.maxInvocations < updatedCollection.invocations) {
            revert InvalidCollection(CollectionErrorReason.INVALID_MAX_INVOCATIONS);
        }

        updatedCollection.athleteAddress = data.athleteAddress;
        updatedCollection.athletePrimarySalesBPS = data.athletePrimarySalesBPS;
        updatedCollection.athleteSecondarySalesBPS = data.athleteSecondarySalesBPS;
        updatedCollection.fantiumSalesAddress = data.fantiumSalesAddress;
        updatedCollection.fantiumSecondarySalesBPS = data.fantiumSecondarySalesBPS;
        updatedCollection.launchTimestamp = data.launchTimestamp;
        updatedCollection.maxInvocations = data.maxInvocations;
        updatedCollection.otherEarningShare1e7 = data.otherEarningShare1e7;
        updatedCollection.price = data.price;
        updatedCollection.tournamentEarningShare1e7 = data.tournamentEarningShare1e7;
        _collections[collectionId] = updatedCollection;

        emit CollectionUpdated(collectionId, updatedCollection);
    }

    /**
     * @notice Sets the mintable and paused state of collection `collectionId`.
     * A non-mintable collection prevents any minting.
     * A paused collection prevents regular accounts to mint tokens but allow members of the allowlist to mint.
     * @dev Restricted to athlete or manager or admin.
     * @param collectionId The collection ID to set the status of.
     * @param isMintable The new mintable state of the collection.
     * @param isPaused The new paused state of the collection.
     */
    function setCollectionStatus(
        uint256 collectionId,
        bool isMintable,
        bool isPaused
    )
        external
        whenNotPaused
        onlyValidCollectionId(collectionId)
        onlyAthleteOrManagerOrAdmin(collectionId)
    {
        _collections[collectionId].isMintable = isMintable;
        _collections[collectionId].isPaused = isPaused;
    }

    // ========================================================================
    // Revenue splits
    // ========================================================================
    /**
     * @notice Returns the primary revenue splits for a given collection and amount.
     * @dev The share formula is based on the BPS values set for the collection on a 10,000 basis.
     * @param collectionId collection ID to be queried.
     * @param amount The amount to share between the athlete and FANtium.
     * @return fantiumRevenue amount of revenue to be sent to FANtium
     * @return fantiumAddress address to send FANtium revenue to
     * @return athleteRevenue amount of revenue to be sent to athlete
     * @return athleteAddress address to send athlete revenue to
     */
    function getPrimaryRevenueSplits(
        uint256 collectionId,
        uint256 amount
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
        athleteRevenue = (amount * collection.athletePrimarySalesBPS) / BPS_BASE;
        fantiumRevenue = amount - athleteRevenue;

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
        Collection memory collection = _collections[collectionId];
        if (!collection.isMintable) {
            revert InvalidMint(MintErrorReason.COLLECTION_NOT_MINTABLE);
        }

        if (collection.launchTimestamp > block.timestamp) {
            revert InvalidMint(MintErrorReason.COLLECTION_NOT_LAUNCHED);
        }

        if (!userManager.isKYCed(recipient)) {
            revert InvalidMint(MintErrorReason.ACCOUNT_NOT_KYCED);
        }

        // If the collection is paused, we need to check if the recipient is on the allowlist and has enough allocation
        if (collection.isPaused) {
            useAllowList = true;
            bool isAllowListed = userManager.allowlist(recipient, collectionId) >= quantity;
            if (!isAllowListed) {
                revert InvalidMint(MintErrorReason.COLLECTION_PAUSED);
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
        uint256 tokenId = (collectionId * MAX_COLLECTIONS) + collection.invocations;

        bool useAllowList = mintable(collectionId, quantity, recipient);

        _collections[collectionId].invocations += quantity;
        if (useAllowList) {
            userManager.decreaseAllowList(recipient, collectionId, quantity);
        }

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
            keccak256(abi.encode(collectionId, quantity, recipient, amount, nonces[recipient])).toEthSignedMessageHash();
        if (!hasRole(SIGNER_ROLE, hash.recover(signature))) {
            revert InvalidMint(MintErrorReason.INVALID_SIGNATURE);
        }

        nonces[recipient]++;
        return _mintTo(collectionId, quantity, amount, recipient);
    }

    function batchTransferFrom(address from, address to, uint256[] memory tokenIds) public whenNotPaused {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            transferFrom(from, to, tokenIds[i]);
        }
    }

    function batchSafeTransferFrom(address from, address to, uint256[] memory tokenIds) public whenNotPaused {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            safeTransferFrom(from, to, tokenIds[i]);
        }
    }

    // ========================================================================
    // Claiming functions
    // ========================================================================
    /**
     * @notice upgrade token version to new version in case of claim event.
     * @dev Restricted to TOKEN_UPGRADER_ROLE.
     * @param tokenId The token ID to upgrade.
     */
    function upgradeTokenVersion(uint256 tokenId)
        external
        onlyRole(TOKEN_UPGRADER_ROLE)
        whenNotPaused
        returns (uint256)
    {
        (uint256 collectionId, uint256 tokenVersion, uint256 number,) = TokenVersionUtil.getTokenInfo(tokenId);
        tokenVersion++;

        if (!_collections[collectionId].exists) {
            revert InvalidUpgrade(UpgradeErrorReason.INVALID_COLLECTION_ID);
        }

        _requireMinted(tokenId);

        if (tokenVersion > TokenVersionUtil.MAX_VERSION) {
            revert InvalidUpgrade(UpgradeErrorReason.VERSION_ID_TOO_HIGH);
        }

        address owner = ownerOf(tokenId);
        _burn(tokenId); // burn old token

        uint256 newTokenId = TokenVersionUtil.createTokenId(collectionId, tokenVersion, number);
        _mint(owner, newTokenId);
        return newTokenId;
    }
}
