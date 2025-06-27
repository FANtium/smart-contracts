// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IFANtiumAthletes.sol";

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {
    ERC721Upgradeable,
    IERC165Upgradeable,
    IERC721Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { StringsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import { ECDSAUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import {
    Collection,
    CollectionData,
    CollectionErrorReason,
    IFANtiumAthletes,
    MintErrorReason,
    UpgradeErrorReason
} from "src/interfaces/IFANtiumAthletes.sol";
import { Rescue } from "src/utils/Rescue.sol";
import { TokenVersionUtil } from "src/utils/TokenVersionUtil.sol";

/**
 * @title FANtium Athletes ERC721 contract V10.
 * @author Mathieu Bour, Alex Chernetsky - FANtium AG, based on previous work by MTX studio AG.
 * @custom:oz-upgrades-from src/archive/FANtiumAthletesV9.sol:FANtiumAthletesV9
 */
contract FANtiumAthletesV11 is
    Initializable,
    ERC721Upgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    Rescue,
    IFANtiumAthletes,
    EIP712Upgradeable
{
    using StringsUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

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
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    /**
     * @notice Role for the token upgrader.
     * @dev Used to upgrade the token to a new version.
     */
    bytes32 public constant TOKEN_UPGRADER_ROLE = keccak256("TOKEN_UPGRADER_ROLE");

    /**
     * @notice Trusted operator role that can approve all transfers - only first party operators are allowed.
     * @dev Used by the marketplace to approve transfers.
     */
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice EIP-712 typehash for KYC status struct
    bytes32 public constant VERIFICATION_STATUS_TYPEHASH =
        keccak256("VerificationStatus(address account,uint8 level,uint256 expiresAt)");

    // ========================================================================
    // State variables
    // ========================================================================
    /**
     * @notice Mapping of collection IDs to collection data.
     * @custom:oz-retyped-from mapping(uint256 => Collection)
     */
    mapping(uint256 => Collection) private _collections;

    /**
     * @notice The base URI for the token metadata.
     */
    string public baseURI;

    /**
     * @notice Mapping of collection IDs to allowlist allocations.
     * @dev Deprecated: replaced by the userManager contract.
     */
    mapping(uint256 => mapping(address => uint256)) private UNUSED_collectionIdToAllowList;

    /**
     * @notice Mapping of addresses that have been KYCed.
     * @dev Deprecated: replaced by the userManager contract.
     */
    mapping(address => bool) private UNUSED_kycedAddresses;

    /**
     * @notice The next collection ID to be used.
     */
    uint256 public nextCollectionId;

    /**
     * @notice The ERC20 token used for payments, usually a stablecoin.
     */
    IERC20MetadataUpgradeable public erc20PaymentToken;

    /**
     * @dev Deprecated: replaced by the TOKEN_UPGRADER_ROLE.
     */
    address private UNUSED_claimContract;

    /**
     * @dev Deprecated: kept for upgrade compatibility
     * @custom:oz-renamed-from userManager
     */
    address private UNUSED_userManager;

    /**
     * @dev Deprecated: replaced by the FORWARDER_ROLE.
     */
    address private UNUSED_trustedForwarder;

    /**
     * @notice Mapping of addresses to their nonce.
     * @dev Used to prevent replay attacks with the mintTo function.
     */
    mapping(address => uint256) public nonces;

    /**
     * @dev The FANtium treasury address.
     */
    address payable public treasury;

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
        __EIP712_init("FANtium", "11");
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
    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    // ========================================================================
    // Modifiers
    // ========================================================================
    modifier onlyAthleteOrAdmin(uint256 collectionId) {
        if (_msgSender() != _collections[collectionId].athleteAddress && !hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert AthleteOnly(collectionId, _msgSender(), _collections[collectionId].athleteAddress);
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
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */
    function unpause() external onlyAdmin {
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
        override (IERC165Upgradeable, AccessControlUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ========================================================================
    // Setters
    // ========================================================================
    /**
     * @notice Sets the base URI for the token metadata.
     * @dev Restricted to admin.
     * @param baseURI_ The new base URI.
     */
    function setBaseURI(string memory baseURI_) external whenNotPaused onlyAdmin {
        baseURI = baseURI_;
    }

    /**
     * @notice Sets the ERC20 payment token.
     * @dev Restricted to admin.
     * @param _erc20PaymentToken The new ERC20 payment token.
     */
    function setERC20PaymentToken(IERC20MetadataUpgradeable _erc20PaymentToken) external whenNotPaused onlyAdmin {
        erc20PaymentToken = _erc20PaymentToken;
    }

    /**
     * @notice Sets the FANtium treasury address.
     * @dev Restricted to admin.
     * @param _treasury The new FANtium treasury address.
     */
    function setTreasury(address payable _treasury) external whenNotPaused onlyAdmin {
        treasury = _treasury;
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

    /**
     * @notice Returns true if `operator` is allowed to manage all of `owner`'s assets.
     * @dev First party operators are allowed to manage all assets without restrictions.
     */
    function isApprovedForAll(
        address owner,
        address operator
    )
        public
        view
        override (ERC721Upgradeable, IERC721Upgradeable)
        returns (bool)
    {
        if (hasRole(OPERATOR_ROLE, operator)) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
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
     * @dev Restricted to admin.
     * @param data The new collection data.
     * @return collectionId The ID of the created collection.
     */
    function createCollection(CollectionData memory data) external whenNotPaused onlyAdmin returns (uint256) {
        _checkCollectionData(data);

        uint256 collectionId = nextCollectionId++;
        Collection memory newCollection = Collection({
            athleteAddress: data.athleteAddress,
            athletePrimarySalesBPS: data.athletePrimarySalesBPS,
            athleteSecondarySalesBPS: data.athleteSecondarySalesBPS,
            exists: true,
            UNUSED_fantiumSalesAddress: payable(address(0)),
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
     * @dev Restricted to admin.
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
        onlyAdmin
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
        onlyAthleteOrAdmin(collectionId)
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
        fantiumAddress = treasury;
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
            erc20PaymentToken.safeTransferFrom(_sender, fantiumAddress_, fantiumRevenue_);
        }

        // athlete payment
        if (athleteRevenue_ > 0) {
            erc20PaymentToken.safeTransferFrom(_sender, athleteAddress_, athleteRevenue_);
        }
    }

    // ========================================================================
    // Minting
    // ========================================================================
    /**
     * @notice Checks if a mint is possible for a collection
     * @param collectionId Collection ID.
     */
    function mintable(uint256 collectionId) public view onlyValidCollectionId(collectionId) {
        Collection memory collection = _collections[collectionId];
        if (!collection.isMintable) {
            revert InvalidMint(MintErrorReason.COLLECTION_NOT_MINTABLE);
        }

        if (collection.launchTimestamp > block.timestamp) {
            revert InvalidMint(MintErrorReason.COLLECTION_NOT_LAUNCHED);
        }

        // If the collection is paused, we need to check if the recipient is on the allowlist and has enough allocation
        if (collection.isPaused) {
            revert InvalidMint(MintErrorReason.COLLECTION_PAUSED);
        }
    }

    /**
     * @notice Calculates the expected price in payment tokens for minting NFTs from a collection
     * @dev Multiplies the collection's base price by quantity and adjusts for the payment token's decimals
     * @param collectionId The ID of the collection to calculate the price for
     * @param quantity The number of NFTs to be minted
     * @return The total price in the smallest unit of the payment token (e.g., wei for ETH, cents for USDC)
     */
    function _expectedPrice(uint256 collectionId, uint24 quantity) internal view returns (uint256) {
        Collection memory collection = _collections[collectionId];
        return collection.price * quantity * 10 ** IERC20MetadataUpgradeable(erc20PaymentToken).decimals();
    }

    /**
     * @dev Internal function to mint tokens of a collection.
     * @param collectionId Collection ID.
     * @param quantity Amount of tokens to mint.
     * @param amount Amount of ERC20 tokens to pay for the mint.
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

        mintable(collectionId);

        _collections[collectionId].invocations += quantity;

        // Send funds to the treasury and athlete account.
        _splitFunds(amount, collectionId, _msgSender());

        for (uint256 i = 0; i < quantity; i++) {
            _mint(recipient, tokenId + i);
        }

        lastTokenId = tokenId + quantity - 1;

        uint256 expectedPrice = _expectedPrice(collectionId, quantity);
        // expectedPrice can theoretically be higher than paid amount
        uint256 discount = expectedPrice >= amount ? expectedPrice - amount : 0;
        emit Sale(collectionId, quantity, recipient, amount, discount);
    }

    // todo: this fn should be removed in favour of new one
    /**
     * @notice Purchase NFTs from the sale.
     * @param collectionId The collection ID to purchase from.
     * @param quantity The quantity of NFTs to purchase.
     * @param recipient The recipient of the NFTs.
     */
    function mintTo(uint256 collectionId, uint24 quantity, address recipient) public whenNotPaused returns (uint256) {
        uint256 amount = _expectedPrice(collectionId, quantity);
        return _mintTo(collectionId, quantity, amount, recipient);
    }

    // todo: this fn should be removed in favour of new one
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

    // ========================================================================
    /**
     * @dev Verifies the KYC status signature
     * @param verificationStatus The KYC status to verify
     * @param signature The backend-generated signature for user purchasing the athlete NFT
     */
    function _verifySignature(VerificationStatus calldata verificationStatus, bytes calldata signature) internal view {
        bytes32 kycStatusHash = keccak256(
            abi.encode(
                VERIFICATION_STATUS_TYPEHASH,
                verificationStatus.account,
                verificationStatus.level,
                verificationStatus.expiresAt
            )
        );

        bytes32 digest = _hashTypedDataV4(kycStatusHash);
        address signer = ECDSA.recover(digest, signature);

        if (!hasRole(SIGNER_ROLE, signer)) {
            revert InvalidMint(MintErrorReason.INVALID_SIGNATURE);
        }
    }

    // todo: 1. implement new mintTo fn - done
    // todo: 2. add new tests - done
    // todo: 3. change contract version to v11 - done
    // todo: 4. remove old mintTo functions
    // todo: 5. deploy updated contract to dev
    /**
     * @notice Purchase NFTs from the sale.
     * @param mintRequest All the data required for purchase: collectionId, quantity, recipient etc.
     * @param signature The backend-generated signature for user purchasing the athlete NFT
     */
    function mintTo(
        MintRequest calldata mintRequest,
        bytes calldata signature
    )
        public
        whenNotPaused
        returns (uint256)
    {
        _verifySignature(mintRequest.verificationStatus, signature);

        // purchase requires AML check (level 1)
        if (mintRequest.verificationStatus.level < 1) {
            revert InvalidMint(MintErrorReason.ACCOUNT_NOT_KYCED);
        }

        if (mintRequest.verificationStatus.expiresAt < block.timestamp) {
            revert InvalidMint(MintErrorReason.SIGNATURE_EXPIRED);
        }

        // todo: calculate amount VS use mintRequest.amount ?
        uint256 amount = _expectedPrice(mintRequest.collectionId, mintRequest.quantity);
        return _mintTo(mintRequest.collectionId, mintRequest.quantity, amount, mintRequest.recipient);
    }

    // ========================================================================
    // Batch transfer functions
    // ========================================================================
    /**
     * @notice Batch transfer NFTs from one address to another.
     * @param from The address to transfer the NFTs from.
     * @param to The address to transfer the NFTs to.
     * @param tokenIds The IDs of the NFTs to transfer.
     */
    function batchTransferFrom(address from, address to, uint256[] memory tokenIds) public whenNotPaused {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            transferFrom(from, to, tokenIds[i]);
        }
    }

    /**
     * @notice Batch safe transfer NFTs from one address to another.
     * @param from The address to transfer the NFTs from.
     * @param to The address to transfer the NFTs to.
     * @param tokenIds The IDs of the NFTs to transfer.
     */
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

    // ========================================================================
    // Rescue functions
    // ========================================================================
    /**
     * @notice Authorizes a rescue of a token by checking if the sender has the DEFAULT_ADMIN_ROLE
     */
    function _authorizeRescue(uint256, address, string calldata) internal view override {
        _checkRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Rescues a single token by transferring it to a specified address
     * @param tokenId The ID of the token to rescue
     * @param recipient The address that received the rescued token
     */
    function _rescue(uint256 tokenId, address recipient, string calldata) internal override {
        _transfer(ownerOf(tokenId), recipient, tokenId);
    }
}
