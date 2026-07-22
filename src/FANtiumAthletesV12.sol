// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {
    IERC20MetadataUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {
    ERC721Upgradeable,
    IERC165Upgradeable,
    IERC721Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { StringsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import { ECDSAUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {
    Collection,
    CollectionData,
    CollectionErrorReason,
    IFANtiumAthletes,
    MintErrorReason,
    PhaseSeed,
    PricePhase,
    SaleStatus,
    UpgradeErrorReason
} from "src/interfaces/IFANtiumAthletes.sol";
import { Rescue } from "src/utils/Rescue.sol";
import { TokenVersionUtil } from "src/utils/TokenVersionUtil.sol";

/**
 * @title FANtium Athletes ERC721 contract V12.
 * @notice The FANtium athletes collections: backend-authorized mints priced by on-chain phases.
 * @author Mathieu Bour, Alex Chernetsky - FANtium AG, based on previous work by MTX studio AG.
 * @custom:oz-upgrades-from archive:FANtiumAthletesV11
 */
contract FANtiumAthletesV12 is
    Initializable,
    ERC721Upgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    Rescue,
    IFANtiumAthletes
{
    using StringsUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    // ========================================================================
    // Constants
    // ========================================================================
    string private constant NAME = "FANtium";
    string private constant SYMBOL = "FAN";

    uint256 private constant BPS_BASE = 10_000;
    uint256 private constant MAX_COLLECTIONS = 1_000_000;
    uint256 private constant MAX_INVOCATIONS = 10_000;

    // EIP-712
    // ========================================================================
    /// @notice EIP-712 domain typehash.
    bytes32 public constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    /// @notice Typehash of the `Mint` struct signed by `SIGNER_ROLE` to authorize mints.
    /// @dev The signature only authorizes *who* may mint *what*; the price is always the on-chain
    ///      phase quote (`quoteMint`) at execution time. The buyer's exact-amount ERC20
    ///      approval acts as slippage protection if the sale progresses between quoting and
    ///      execution.
    bytes32 public constant MINT_TYPEHASH =
        keccak256("Mint(uint256 collectionId,uint24 quantity,address recipient,uint256 nonce,uint256 deadline)");
    bytes32 private constant _EIP712_NAME_HASH = keccak256(bytes("FANtium Athletes"));
    bytes32 private constant _EIP712_VERSION_HASH = keccak256(bytes("1"));

    // Roles
    // ========================================================================
    /// @notice Role for the ERC2771 trusted forwarders, allowed to relay meta-transactions.
    bytes32 public constant FORWARDER_ROLE = keccak256("FORWARDER_ROLE");

    /// @notice Role for the backend signers authorized to sign `Mint` authorizations.
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
     * @notice The FANtium treasury address, receiving the FANtium share of primary sales.
     */
    address payable public treasury;

    // ========================================================================
    // UUPS upgradeable pattern
    // ========================================================================
    /**
     * @notice Locks the implementation contract; the proxy is initialized via `initialize`.
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
     * @notice V12 storage migration: seeds `phases` and `status` on every pre-V12 collection.
     * @dev Intended to be executed atomically with the implementation switch via
     *      `upgradeToAndCall(implementation, abi.encodeCall(this.initializeV12, (seeds)))`, so there
     *      is no window where collections exist without phases. Two-step migration:
     *      1. Every collection gets a one-element phases array from its legacy single price tier
     *         (`UNUSED_price`/`UNUSED_maxInvocations`), and `status` derived from the legacy
     *         booleans (see `_migrateCollectionV12`).
     *      2. The provided `seeds` (full multi-phase schedules, generated off-chain from the Strapi
     *         discount sections by `scripts/generatePhaseSeeds.ts`) then overwrite the phases of
     *         the listed collections, replacing the manual "bump price and extend supply per
     *         tranche" ops process with on-chain phase pricing.
     *      Seeds are validated like any phases update; an invalid seed reverts the whole upgrade.
     * @param seeds Multi-phase schedules to apply on top of the single-phase default migration.
     */
    function initializeV12(PhaseSeed[] calldata seeds) external reinitializer(12) onlyAdmin {
        for (uint256 collectionId = 1; collectionId < nextCollectionId; ++collectionId) {
            _migrateCollectionV12(collectionId);
        }

        for (uint256 i = 0; i < seeds.length; ++i) {
            if (!_collections[seeds[i].collectionId].exists) {
                revert InvalidCollectionId(seeds[i].collectionId);
            }
            _validatePhases(seeds[i].collectionId, seeds[i].phases);
            _writePhases(seeds[i].collectionId, seeds[i].phases);
        }
    }

    /**
     * @notice Escape hatch: migrates collections `[fromId, toId]` in a standalone transaction.
     * @dev Only needed if the collection count ever makes `initializeV12` exceed the block gas
     *      limit (upgrade via plain `upgradeTo`, then migrate in chunks). Idempotent: collections
     *      that already have phases are skipped.
     * @param fromId First collection ID to migrate (inclusive).
     * @param toId Last collection ID to migrate (inclusive).
     */
    function migrateCollectionsV12(uint256 fromId, uint256 toId) external onlyAdmin {
        for (uint256 collectionId = fromId; collectionId <= toId; ++collectionId) {
            _migrateCollectionV12(collectionId);
        }
    }

    /**
     * @notice Migrates a single pre-V12 collection; no-op if it does not exist or already has phases.
     * @dev Status derivation from the legacy booleans:
     *      - isMintable && !isPaused          => Open
     *      - isMintable && isPaused           => Closed (every legacy "paused" sale was in fact meant
     *                                            to be closed; an admin can reopen if ever needed)
     *      - !isMintable && invocations > 0   => Closed (sale had started, then was switched off)
     *      - !isMintable && invocations == 0  => Pending (sale never started)
     * @param collectionId The collection ID to migrate.
     */
    function _migrateCollectionV12(uint256 collectionId) internal {
        Collection storage collection = _collections[collectionId];
        if (!collection.exists || collection.phases.length != 0) {
            return;
        }

        collection.phases
            .push(
                PricePhase({
                    price: uint128(collection.UNUSED_price), maxInvocations: uint128(collection.UNUSED_maxInvocations)
                })
            );

        if (collection.UNUSED_isMintable) {
            collection.status = collection.UNUSED_isPaused ? SaleStatus.Closed : SaleStatus.Open;
        } else if (collection.invocations > 0) {
            collection.status = SaleStatus.Closed;
        }
        // else: stays Pending (enum default)
    }

    /**
     * @notice Implementation of the upgrade authorization logic
     * @dev Restricted to the DEFAULT_ADMIN_ROLE. The new implementation address parameter is
     *      unnamed: it is unused by the check.
     */
    // solhint-disable-next-line use-natspec
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
    /**
     * @notice Returns true if `forwarder` is an ERC2771 trusted forwarder.
     * @param forwarder The address to check.
     * @return True if `forwarder` holds the `FORWARDER_ROLE`.
     */
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return hasRole(FORWARDER_ROLE, forwarder);
    }

    /**
     * @notice ERC2771-aware message sender resolution.
     * @return sender The original sender for relayed calls, `msg.sender` otherwise.
     */
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

    /**
     * @notice ERC2771-aware calldata resolution.
     * @return The original calldata, stripped of the appended sender for relayed calls.
     */
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
    /**
     * @notice Returns true if this contract implements the interface defined by `interfaceId`.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return True if the interface is supported.
     */
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
    function setBaseURI(string calldata baseURI_) external whenNotPaused onlyAdmin {
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
     * @notice Returns the base URI for computing {tokenURI}.
     * @dev Necessary to use the default ERC721 tokenURI function from ERC721Upgradeable.
     * @return The base URI for the token metadata.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /**
     * @notice Returns true if `operator` is allowed to manage all of `owner`'s assets.
     * @dev First party operators are allowed to manage all assets without restrictions.
     * @param owner The owner of the assets.
     * @param operator The operator to check.
     * @return True if `operator` is approved to manage all of `owner`'s assets.
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
    /**
     * @notice Returns the collection data for `_collectionId`.
     * @param _collectionId The collection ID to query.
     * @return The collection struct, including its phases and sale status.
     */
    function collections(uint256 _collectionId) external view returns (Collection memory) {
        return _collections[_collectionId];
    }

    /**
     * @notice Validates a `CollectionData` payload against domain invariants.
     * @dev Checks basic fields (athlete address, BPS sums, earning shares, max collections) and
     *      the phases array (non-empty, non-zero sub-supplies, total under `MAX_INVOCATIONS`,
     *      a total supply that still covers current `invocations` for mid-sale updates — equality
     *      is allowed, representing a sold-out collection).
     *      For create flows pass the about-to-be-assigned `collectionId`; the collection's
     *      `invocations` will read as zero and the accommodation check becomes a no-op.
     * @param collectionId The collection ID being validated against.
     * @param data The proposed collection data.
     */
    function _validateCollectionData(uint256 collectionId, CollectionData calldata data) internal view {
        if (data.athleteAddress == address(0)) {
            revert InvalidCollection(CollectionErrorReason.INVALID_ATHLETE_ADDRESS);
        }

        if (data.athletePrimarySalesBPS > BPS_BASE) {
            revert InvalidCollection(CollectionErrorReason.INVALID_PRIMARY_SALES_BPS);
        }

        if (data.athleteSecondarySalesBPS + data.fantiumSecondarySalesBPS > BPS_BASE) {
            revert InvalidCollection(CollectionErrorReason.INVALID_BPS_SUM);
        }

        if (data.otherEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_OTHER_EARNING_SHARE);
        }

        if (data.tournamentEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_TOURNAMENT_EARNING_SHARE);
        }

        if (nextCollectionId >= MAX_COLLECTIONS) {
            revert InvalidCollection(CollectionErrorReason.MAX_COLLECTIONS_REACHED);
        }

        _validatePhases(collectionId, data.phases);
    }

    /**
     * @notice Validates a phases array against domain invariants: non-empty, non-zero sub-supplies,
     *         total under `MAX_INVOCATIONS`, and a total supply that still covers the collection's
     *         current `invocations` (equality is allowed, representing a sold-out collection).
     * @param collectionId The collection ID being validated against.
     * @param phases The proposed phases array.
     */
    function _validatePhases(uint256 collectionId, PricePhase[] calldata phases) internal view {
        uint256 length = phases.length;
        if (length == 0) {
            revert PhasesNotConfigured(collectionId);
        }

        uint256 cumulative = 0;

        for (uint256 i = 0; i < length; ++i) {
            uint128 phaseMax = phases[i].maxInvocations;
            if (phaseMax == 0) {
                revert PhaseMaxInvocationsZero(i);
            }
            cumulative += phaseMax;
        }

        if (cumulative >= MAX_INVOCATIONS) {
            revert InvalidCollection(CollectionErrorReason.INVALID_MAX_INVOCATIONS);
        }

        // Equality is allowed: it represents a sold-out collection.
        if (cumulative < _collections[collectionId].invocations) {
            revert PhasesMustAccommodateInvocations(_collections[collectionId].invocations);
        }
    }

    /**
     * @notice Replaces `_collections[collectionId].phases` with the provided array.
     * @param collectionId The collection ID to write the phases of.
     * @param phases The new phases array.
     */
    function _writePhases(uint256 collectionId, PricePhase[] calldata phases) internal {
        delete _collections[collectionId].phases;
        for (uint256 i = 0; i < phases.length; ++i) {
            _collections[collectionId].phases.push(phases[i]);
        }
    }

    /**
     * @notice Replaces the price phases of collection `collectionId` without touching any other
     *         field (unlike `updateCollection`, which requires re-supplying the full payload).
     * @dev Restricted to admin. Mid-sale updates must leave the active phase well-defined —
     *      the phases' total supply must still cover the current `invocations`.
     * @param collectionId The collection ID to update.
     * @param phases The new phases array.
     */
    function setPhases(
        uint256 collectionId,
        PricePhase[] calldata phases
    )
        external
        whenNotPaused
        onlyValidCollectionId(collectionId)
        onlyAdmin
    {
        _validatePhases(collectionId, phases);
        _writePhases(collectionId, phases);

        emit CollectionUpdated(collectionId, _collections[collectionId]);
    }

    /**
     * @notice Creates a new collection.
     * @dev Restricted to admin.
     * @param data The new collection data.
     * @return collectionId The ID of the created collection.
     */
    function createCollection(CollectionData calldata data) external whenNotPaused onlyAdmin returns (uint256) {
        uint256 collectionId = nextCollectionId;
        ++nextCollectionId;
        _validateCollectionData(collectionId, data);

        Collection storage stored = _collections[collectionId];
        stored.exists = true;
        stored.launchTimestamp = data.launchTimestamp;
        // stored.status is left untouched: collection ids are never reused, so the slot is zero
        // and the sale starts as SaleStatus.Pending.
        stored.tournamentEarningShare1e7 = data.tournamentEarningShare1e7;
        stored.athleteAddress = data.athleteAddress;
        stored.athletePrimarySalesBPS = data.athletePrimarySalesBPS;
        stored.athleteSecondarySalesBPS = data.athleteSecondarySalesBPS;
        stored.fantiumSecondarySalesBPS = data.fantiumSecondarySalesBPS;
        stored.otherEarningShare1e7 = data.otherEarningShare1e7;

        _writePhases(collectionId, data.phases);

        emit CollectionCreated(collectionId, _collections[collectionId]);

        return collectionId;
    }

    /**
     * @notice Updates a collection.
     * @dev Restricted to admin. The phases array is fully replaced with `data.phases`.
     *      Mid-sale updates must leave the active phase well-defined — cumulative sums
     *      must still cover the current `invocations`.
     * @param collectionId The collection ID to update.
     * @param data The new collection data.
     */
    function updateCollection(
        uint256 collectionId,
        CollectionData calldata data
    )
        external
        onlyValidCollectionId(collectionId)
        whenNotPaused
        onlyAdmin
    {
        _validateCollectionData(collectionId, data);

        Collection storage stored = _collections[collectionId];
        stored.athleteAddress = data.athleteAddress;
        stored.athletePrimarySalesBPS = data.athletePrimarySalesBPS;
        stored.athleteSecondarySalesBPS = data.athleteSecondarySalesBPS;
        stored.fantiumSecondarySalesBPS = data.fantiumSecondarySalesBPS;
        stored.launchTimestamp = data.launchTimestamp;
        stored.otherEarningShare1e7 = data.otherEarningShare1e7;
        stored.tournamentEarningShare1e7 = data.tournamentEarningShare1e7;

        _writePhases(collectionId, data.phases);

        emit CollectionUpdated(collectionId, _collections[collectionId]);
    }

    /**
     * @notice Sets the sale status of every collection in `collectionIds`.
     * @dev Restricted to athlete or admin, checked per collection — an athlete can batch only
     *      their own collections. `Closed` is terminal for athletes: once a sale is closed, only
     *      an admin can move it to another status. Any failing collection reverts the whole batch.
     * @param collectionIds The collection IDs to set the status of.
     * @param status The new sale status, applied to all listed collections.
     */
    function setSaleStatus(uint256[] calldata collectionIds, SaleStatus status) external whenNotPaused {
        bool isAdmin = hasRole(DEFAULT_ADMIN_ROLE, _msgSender());

        for (uint256 i = 0; i < collectionIds.length; ++i) {
            uint256 collectionId = collectionIds[i];
            Collection storage collection = _collections[collectionId];

            if (!collection.exists) {
                revert InvalidCollectionId(collectionId);
            }

            if (!isAdmin && _msgSender() != collection.athleteAddress) {
                revert AthleteOnly(collectionId, _msgSender(), collection.athleteAddress);
            }

            if (!isAdmin && collection.status == SaleStatus.Closed) {
                revert SaleClosed(collectionId);
            }

            collection.status = status;
            emit SaleStatusUpdated(collectionId, status);
        }
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
     * @notice Splits funds between FANtium and the athlete for a purchase on collection `_collectionId`.
     * @param _price The total amount of payment tokens to split.
     * @param _collectionId The collection the purchase belongs to.
     * @param _sender The buyer paying for the purchase.
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
     * @notice Returns the current EIP-712 domain separator, bound to `block.chainid` and `address(this)`.
     * @dev Computed on-the-fly to avoid storage and stay compatible with proxy upgrades across chain forks.
     * @return The EIP-712 domain separator.
     */
    function domainSeparator() public view returns (bytes32) {
        return keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, _EIP712_NAME_HASH, _EIP712_VERSION_HASH, block.chainid, address(this))
        );
    }

    /**
     * @notice Quotes a purchase of `quantity` tokens, walking the phases from the collection's
     *         current position. A purchase may span several phases: each segment is charged at its
     *         own phase price (e.g. 2 tokens left at 10 + 3 tokens at 20 = 80). This is exactly
     *         what `mintTo` charges at execution time; the backend/frontend use it to display
     *         prices and size ERC20 approvals.
     * @dev Reverts only when the phases are missing or the total remaining supply is insufficient.
     * @param collectionId The collection to quote.
     * @param quantity The number of tokens to purchase. A zero-quantity quote returns a zero price
     *        and meaningless phase indices (`mintTo` rejects `quantity == 0`).
     * @return price Total price in the smallest unit of the payment token (e.g. cents for USDC).
     * @return activePhaseBefore Index of the active phase before the purchase.
     * @return activePhaseAfter Index of the active phase after the purchase; only meaningful when
     *         `soldOutAfter` is false.
     * @return soldOutAfter True when the purchase consumes the collection's entire supply.
     */
    function quoteMint(
        uint256 collectionId,
        uint24 quantity
    )
        public
        view
        returns (uint256 price, uint256 activePhaseBefore, uint256 activePhaseAfter, bool soldOutAfter)
    {
        PricePhase[] storage phases = _collections[collectionId].phases;
        uint256 length = phases.length;
        if (length == 0) {
            revert PhasesNotConfigured(collectionId);
        }

        // Purchased range in invocation-space: [from, to).
        uint256 from = _collections[collectionId].invocations;
        uint256 to = from + quantity;
        uint256 phaseStart = 0;
        uint256 cost = 0;
        bool startFound = false;
        bool afterFound = false;

        for (uint256 i = 0; i < length; ++i) {
            PricePhase memory phase = phases[i];
            uint256 phaseEnd = phaseStart + phase.maxInvocations;

            // Overlap of [from, to) with this phase's range [phaseStart, phaseEnd).
            uint256 lo = from > phaseStart ? from : phaseStart;
            uint256 hi = to < phaseEnd ? to : phaseEnd;
            if (lo < hi) {
                cost += (hi - lo) * phase.price;
                if (!startFound) {
                    activePhaseBefore = i;
                    startFound = true;
                }
            }

            // The first phase whose end lies strictly beyond `to` is the active phase afterwards.
            if (!afterFound && to < phaseEnd) {
                activePhaseAfter = i;
                afterFound = true;
            }

            phaseStart = phaseEnd;
        }

        // Not enough supply left across all phases.
        if (to > phaseStart) {
            revert InvalidMint(MintErrorReason.MAX_INVOCATIONS_REACHED);
        }

        soldOutAfter = !afterFound;
        price = cost * 10 ** IERC20MetadataUpgradeable(erc20PaymentToken).decimals();
    }

    /**
     * @notice Returns the EIP-712 digest a `SIGNER_ROLE` holder must sign to authorize a mint.
     * @dev Exposed so backends and tests can introspect the exact digest without replicating the
     *      hashing math. Mirrors `EIP712Upgradeable._hashTypedDataV4` without inheriting it
     *      (avoids storage-layout shift), delegating the `\x19\x01`-prefixed envelope to OZ's pure
     *      helper `ECDSAUpgradeable.toTypedDataHash`.
     * @param collectionId The collection ID to purchase from.
     * @param quantity The quantity of NFTs to purchase.
     * @param recipient The recipient of the NFTs.
     * @param nonce The `nonces[recipient]` value at the time of signing.
     * @param deadline UNIX timestamp after which the signature is no longer valid.
     * @return The 32-byte EIP-712 digest to sign.
     */
    function hashMint(
        uint256 collectionId,
        uint24 quantity,
        address recipient,
        uint256 nonce,
        uint256 deadline
    )
        public
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(abi.encode(MINT_TYPEHASH, collectionId, quantity, recipient, nonce, deadline));
        return ECDSAUpgradeable.toTypedDataHash(domainSeparator(), structHash);
    }

    /**
     * @notice Purchase NFTs from the sale. This is the only mint entry point: every purchase must
     *         be authorized by the FANtium backend via an EIP-712 signature from a `SIGNER_ROLE`
     *         holder. The price charged is always the on-chain phase quote at execution time
     *         (`quoteMint`) — there are no custom or discounted amounts.
     * @dev The buyer's exact-amount ERC20 approval acts as slippage protection: if the sale
     *      progresses past a phase boundary between quoting and execution, the higher charge
     *      exceeds the allowance and the transaction reverts. The `Sale` event's `discount` field
     *      is kept for indexer compatibility and is always zero.
     * @param collectionId The collection ID to purchase from.
     * @param quantity The quantity of NFTs to purchase.
     * @param recipient The recipient of the NFTs.
     * @param deadline UNIX timestamp after which the signature is no longer valid.
     * @param signature EIP-712 signature produced by a `SIGNER_ROLE` holder over the `Mint` struct.
     * @return lastTokenId The ID of the last minted token. Token range is [lastTokenId - quantity + 1, lastTokenId].
     */
    function mintTo(
        uint256 collectionId,
        uint24 quantity,
        address recipient,
        uint256 deadline,
        bytes memory signature
    )
        public
        whenNotPaused
        onlyValidCollectionId(collectionId)
        returns (uint256 lastTokenId)
    {
        if (block.timestamp > deadline) {
            revert InvalidMint(MintErrorReason.SIGNATURE_EXPIRED);
        }

        bytes32 digest = hashMint(collectionId, quantity, recipient, nonces[recipient], deadline);
        if (!hasRole(SIGNER_ROLE, ECDSAUpgradeable.recover(digest, signature))) {
            revert InvalidMint(MintErrorReason.INVALID_SIGNATURE);
        }

        ++nonces[recipient];

        if (quantity == 0) {
            revert InvalidMint(MintErrorReason.INVALID_QUANTITY);
        }

        // Sale state checks
        Collection storage collection = _collections[collectionId];

        if (collection.status == SaleStatus.Paused) {
            revert InvalidMint(MintErrorReason.COLLECTION_PAUSED);
        }

        // Pending or Closed
        if (collection.status != SaleStatus.Open) {
            revert InvalidMint(MintErrorReason.COLLECTION_NOT_MINTABLE);
        }

        if (collection.launchTimestamp > block.timestamp) {
            revert InvalidMint(MintErrorReason.COLLECTION_NOT_LAUNCHED);
        }

        (uint256 price, uint256 activePhaseBefore, uint256 activePhaseAfter, bool soldOutAfter) =
            quoteMint(collectionId, quantity);

        uint256 invocationsBefore = collection.invocations;
        uint256 invocationsAfter = invocationsBefore + quantity;
        collection.invocations = uint24(invocationsAfter);

        // Send funds to the treasury and athlete account.
        _splitFunds(price, collectionId, _msgSender());

        uint256 tokenId = (collectionId * MAX_COLLECTIONS) + invocationsBefore;
        for (uint256 i = 0; i < quantity; ++i) {
            _mint(recipient, tokenId + i);
        }

        lastTokenId = tokenId + quantity - 1;

        emit Sale(collectionId, quantity, recipient, price, 0);

        if (!soldOutAfter && activePhaseAfter != activePhaseBefore) {
            emit PhaseAdvanced(collectionId, activePhaseBefore, activePhaseAfter, invocationsAfter);
        }
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
        for (uint256 i = 0; i < tokenIds.length; ++i) {
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
        for (uint256 i = 0; i < tokenIds.length; ++i) {
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
     * @return The new token ID, encoding the incremented version.
     */
    function upgradeTokenVersion(uint256 tokenId)
        external
        onlyRole(TOKEN_UPGRADER_ROLE)
        whenNotPaused
        returns (uint256)
    {
        (uint256 collectionId, uint256 tokenVersion, uint256 number,) = TokenVersionUtil.getTokenInfo(tokenId);
        ++tokenVersion;

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
     * @dev The token ID, recipient and reason parameters are unnamed: they are unused by the check.
     */
    // solhint-disable-next-line use-natspec
    function _authorizeRescue(uint256, address, string calldata) internal view override {
        _checkRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Rescues a single token by transferring it to a specified address
     * @dev The rescue reason parameter is unnamed: it is unused by the transfer.
     * @param tokenId The ID of the token to rescue
     * @param recipient The address that received the rescued token
     */
    // solhint-disable-next-line use-natspec
    function _rescue(uint256 tokenId, address recipient, string calldata) internal override {
        _transfer(ownerOf(tokenId), recipient, tokenId);
    }
}
