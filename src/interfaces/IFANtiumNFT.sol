// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

/**
 * @notice Collection struct
 * @dev CAUTION: Do not change the order of the struct fields!!
 *
 * Difference between isMintable and isPaused:
 * - isMintable false means that nobody can mint new tokens
 * - isPaused true means that the collection is mintable only by member of the collection allowlist
 *
 * price does not take the token decimals into account, which means that if the price is 1,000UDSC,
 * mintTo function will need to multiply the price by 10^decimals of the token.
 */
struct Collection {
    bool exists;
    uint256 launchTimestamp;
    bool isMintable;
    bool isPaused;
    uint24 invocations;
    uint256 price;
    uint256 maxInvocations;
    uint256 tournamentEarningShare1e7;
    address payable athleteAddress;
    uint256 athletePrimarySalesBPS;
    uint256 athleteSecondarySalesBPS;
    address payable fantiumSalesAddress;
    uint256 fantiumSecondarySalesBPS;
    uint256 otherEarningShare1e7;
}

/**
 * @notice Create collection struct
 * @dev Fields may be added.
 */
struct CollectionData {
    address payable athleteAddress;
    uint256 athletePrimarySalesBPS;
    uint256 athleteSecondarySalesBPS;
    address payable fantiumSalesAddress;
    uint256 fantiumSecondarySalesBPS;
    uint256 launchTimestamp;
    uint256 maxInvocations;
    uint256 otherEarningShare1e7;
    uint256 price;
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
    INVALID_SIGNATURE
}

enum UpgradeErrorReason {
    INVALID_COLLECTION_ID,
    VERSION_ID_TOO_HIGH
}

interface IFANtiumNFT is IERC721Upgradeable {
    // ========================================================================
    // Events
    // ========================================================================
    event CollectionCreated(uint256 indexed collectionId, Collection collection);
    event CollectionUpdated(uint256 indexed collectionId, Collection collection);

    // ========================================================================
    // Errors
    // ========================================================================
    error InvalidCollectionId(uint256 collectionId);
    error AthleteOnly(uint256 collectionId, address account, address expected);
    error InvalidCollection(CollectionErrorReason reason);
    error InvalidMint(MintErrorReason reason);
    error InvalidUpgrade(UpgradeErrorReason reason);

    // ========================================================================
    // Collection
    // ========================================================================
    function collections(uint256 collectionId) external view returns (Collection memory);
    function createCollection(CollectionData memory data) external returns (uint256);
    function updateCollection(uint256 collectionId, CollectionData memory data) external;
    function setCollectionStatus(uint256 collectionId, bool isMintable, bool isPaused) external;

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
    function mintTo(uint256 collectionId, uint24 quantity, address recipient) external returns (uint256);

    function mintTo(
        uint256 collectionId,
        uint24 quantity,
        address recipient,
        uint256 amount,
        bytes memory signature
    )
        external
        returns (uint256);

    // ========================================================================
    // Claiming
    // ========================================================================
    function upgradeTokenVersion(uint256 tokenId) external returns (uint256);
}
