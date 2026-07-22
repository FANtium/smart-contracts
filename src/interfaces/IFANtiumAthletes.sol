// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

/**
 * @notice Ordered price phase for a collection. phases[0] sells first; once its
 *         `maxInvocations` is consumed, phases[1]'s price applies on subsequent mints, etc.
 * @dev `price` does not take the payment token decimals into account; it must be multiplied
 *      by 10^decimals at mint time. Packed as two `uint128` into one storage slot.
 */
struct PricePhase {
    uint128 price;
    uint128 maxInvocations;
}

/**
 * @notice Phase schedule for one collection, used to seed `Collection.phases` during the V12
 *         storage migration (`initializeV12`). Generated off-chain from the Strapi discount
 *         sections (see `scripts/generatePhaseSeeds.ts`).
 */
struct PhaseSeed {
    uint256 collectionId;
    PricePhase[] phases;
}

/**
 * @notice Lifecycle of a collection's primary sale.
 * @dev `Pending` MUST stay at index 0 so that newly created collections default to it.
 *      "Sold out" is intentionally not a status: it is derived from `invocations` vs the
 *      phases' total supply. `launchTimestamp` remains a separate, time-derived gate on
 *      top of `Open`.
 */
enum SaleStatus {
    /// @notice Sale has not started yet; nothing is mintable.
    Pending,
    /// @notice Sale is live; minting is allowed once `launchTimestamp` has passed.
    Open,
    /// @notice Sale is temporarily halted and expected to resume.
    Paused,
    /// @notice Sale has permanently ended. Only an admin can reopen a closed sale.
    Closed
}

/**
 * @notice Collection struct
 * @dev CAUTION: Do not change the order of the struct fields!!
 *
 * The sale lifecycle is driven by `status` (see `SaleStatus`); the legacy
 * `UNUSED_isMintable`/`UNUSED_isPaused` booleans are retained for storage-slot stability.
 * Price and supply are driven by the `phases` array. `UNUSED_price` and `UNUSED_maxInvocations`
 * are legacy single-tier fields retained for storage-slot stability.
 */
struct Collection {
    /**
     * @notice Always true if the collection exists.
     */
    bool exists;
    /**
     * @notice UNIX timestamp of the collection launch.
     */
    uint256 launchTimestamp;
    /**
     * @dev Deprecated: replaced by `status` (`SaleStatus.Open`).
     */
    bool UNUSED_isMintable;
    /**
     * @dev Deprecated: replaced by `status` (`SaleStatus.Paused`).
     */
    bool UNUSED_isPaused;
    /**
     * @notice Number of minted tokens.
     */
    uint24 invocations;
    /**
     * @dev Deprecated: replaced by `phases[activePhase].price`.
     */
    uint256 UNUSED_price;
    /**
     * @dev Deprecated: replaced by the sum of `phases[i].maxInvocations`.
     */
    uint256 UNUSED_maxInvocations;
    /**
     * @notice Tournament earnings share in 1e7 basis points.
     */
    uint256 tournamentEarningShare1e7;
    /**
     * @notice Address of the athlete.
     */
    address payable athleteAddress;
    /**
     * @notice Athlete primary sales share in 10,000 basis points.
     */
    uint256 athletePrimarySalesBPS;
    /**
     * @notice Athlete secondary sales share in 10,000 basis points.
     */
    uint256 athleteSecondarySalesBPS;
    /**
     * @notice Address of the FANtium sales.
     */
    address payable UNUSED_fantiumSalesAddress;
    /**
     * @notice FANtium secondary sales share in 10,000 basis points.
     */
    uint256 fantiumSecondarySalesBPS;
    /**
     * @notice Other earnings (e.g. sponsorships, royalties, etc.) share in 1e7 basis points.
     */
    uint256 otherEarningShare1e7;
    /**
     * @notice Ordered list of price phases. The active phase is derived from `invocations` and
     *         the cumulative sums of `phases[i].maxInvocations`.
     */
    PricePhase[] phases;
    /**
     * @notice Lifecycle status of the collection's primary sale.
     */
    SaleStatus status;
}

/**
 * @notice Create / update collection struct.
 * @dev Fields may be added. Price and supply are expressed via `phases`.
 */
struct CollectionData {
    address payable athleteAddress;
    uint256 athletePrimarySalesBPS;
    uint256 athleteSecondarySalesBPS;
    uint256 fantiumSecondarySalesBPS;
    uint256 launchTimestamp;
    uint256 otherEarningShare1e7;
    PricePhase[] phases;
    uint256 tournamentEarningShare1e7;
}

enum CollectionErrorReason {
    INVALID_BPS_SUM,
    INVALID_MAX_INVOCATIONS,
    INVALID_PRIMARY_SALES_BPS,
    INVALID_SECONDARY_SALES_BPS,
    MAX_COLLECTIONS_REACHED,
    INVALID_TOURNAMENT_EARNING_SHARE,
    INVALID_OTHER_EARNING_SHARE,
    INVALID_ATHLETE_ADDRESS,
    INVALID_FANTIUM_SALES_ADDRESS,
    INVALID_PRICE
}

enum MintErrorReason {
    INVALID_COLLECTION_ID,
    COLLECTION_NOT_MINTABLE,
    COLLECTION_NOT_LAUNCHED,
    COLLECTION_PAUSED,
    ACCOUNT_NOT_KYCED,
    INVALID_SIGNATURE,
    MAX_INVOCATIONS_REACHED,
    SIGNATURE_EXPIRED,
    INVALID_QUANTITY
}

enum UpgradeErrorReason {
    INVALID_COLLECTION_ID,
    VERSION_ID_TOO_HIGH
}

interface IFANtiumAthletes is IERC721Upgradeable {
    // ========================================================================
    // Events
    // ========================================================================
    event CollectionCreated(uint256 indexed collectionId, Collection collection);
    event CollectionUpdated(uint256 indexed collectionId, Collection collection);
    event Sale(
        uint256 indexed collectionId, uint24 quantity, address indexed recipient, uint256 amount, uint256 discount
    );
    /**
     * @notice Emitted when a mint moves the collection's active phase forward — including across
     *         several phases at once for purchases spanning multiple phase boundaries. Not emitted
     *         when the purchase consumes the last phase entirely (the collection is then sold out
     *         and has no active phase).
     */
    event PhaseAdvanced(uint256 indexed collectionId, uint256 fromIndex, uint256 toIndex, uint256 atInvocation);
    event SaleStatusUpdated(uint256 indexed collectionId, SaleStatus status);

    // ========================================================================
    // Errors
    // ========================================================================
    error InvalidCollectionId(uint256 collectionId);
    error AthleteOnly(uint256 collectionId, address account, address expected);
    error InvalidCollection(CollectionErrorReason reason);
    error InvalidMint(MintErrorReason reason);
    error InvalidUpgrade(UpgradeErrorReason reason);
    error PhasesMustAccommodateInvocations(uint256 invocations);
    error PhaseMaxInvocationsZero(uint256 index);
    error PhasesNotConfigured(uint256 collectionId);
    error SaleClosed(uint256 collectionId);

    // ========================================================================
    // Collection
    // ========================================================================
    function collections(uint256 collectionId) external view returns (Collection memory);
    function createCollection(CollectionData calldata data) external returns (uint256);
    function updateCollection(uint256 collectionId, CollectionData calldata data) external;
    function setSaleStatus(uint256[] calldata collectionIds, SaleStatus status) external;
    function setPhases(uint256 collectionId, PricePhase[] calldata phases) external;

    // ========================================================================
    // Revenue splits
    // ========================================================================
    function getPrimaryRevenueSplits(
        uint256 _collectionId,
        uint256 _price
    )
        external
        view
        returns (
            uint256 fantiumRevenue_,
            address payable fantiumAddress_,
            uint256 athleteRevenue_,
            address payable athleteAddress_
        );

    // ========================================================================
    // Minting
    // ========================================================================
    function quoteMint(
        uint256 collectionId,
        uint24 quantity
    )
        external
        view
        returns (uint256 price, uint256 activePhaseBefore, uint256 activePhaseAfter, bool soldOutAfter);

    function mintTo(
        uint256 collectionId,
        uint24 quantity,
        address recipient,
        uint256 deadline,
        bytes memory signature
    )
        external
        returns (uint256);

    // ========================================================================
    // Claiming
    // ========================================================================
    function upgradeTokenVersion(uint256 tokenId) external returns (uint256);
}
