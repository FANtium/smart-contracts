// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

/**
 * @notice Collection struct
 * @dev /!\ Do not change the order of the struct fields!!
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
struct CreateCollection {
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

struct UpdateCollection {
    uint256 athleteSecondarySalesBPS;
    uint256 maxInvocations;
    uint256 price;
    uint256 tournamentEarningShare1e7;
    uint256 otherEarningShare1e7;
    address payable fantiumSalesAddress;
    uint256 fantiumSecondarySalesBPS;
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

/**
 * @dev Interface of the IFANtiumNFT
 */
interface IFANtiumNFT is IERC721Upgradeable {
    // ========================================================================
    // Events
    // ========================================================================
    event Mint(address indexed _to, uint256 indexed _tokenId);
    event CollectionUpdated(uint256 indexed _collectionId, bytes32 indexed _update);
    event PlatformUpdated(bytes32 indexed _field);

    // ========================================================================
    // Errors
    // ========================================================================
    error InvalidCollectionId(uint256 collectionId);
    error InvalidTokenId(uint256 tokenId);
    error AccountNotKYCed(address recipient);
    error CollectionDoesNotExist(uint256 collectionId);
    error CollectionNotLaunched(uint256 collectionId);
    error CollectionNotMintable(uint256 collectionId);
    error CollectionPaused(uint256 collectionId);
    error InvalidSignature();
    error RoleNotGranted(address account, bytes32 role);
    error AthleteOnly(uint256 collectionId, address account, address expected);
    error InvalidCollection(CollectionErrorReason reason);

    // ========================================================================
    // Collection
    // ========================================================================
    function collections(uint256 collectionId) external view returns (Collection memory);

    function createCollection(CreateCollection memory data) external returns (uint256);

    function updateCollection(uint256 collectionId, UpdateCollection memory data) external;

    function toggleCollectionPaused(uint256 collectionId) external;

    /**
     * @notice upgrades token version. Old token gets burned and new token gets minted to owner of Token
     * @param _tokenId TokenID to be upgraded
     * @return bool if upgrade successfull it returns true
     */
    function upgradeTokenVersion(uint256 _tokenId) external returns (bool);

    function getPrimaryRevenueSplits(uint256 _collectionId, uint256 _price)
        external
        view
        returns (
            uint256 fantiumRevenue_,
            address payable fantiumAddress_,
            uint256 athleteRevenue_,
            address payable athleteAddress_
        );

    /**
     * @notice get royalties for secondary market transfers of token
     * @param _tokenId tokenId of NFT
     * @return recipients array of recepients of royalties
     * @return bps array of bps of royalties
     */
    function getRoyalties(uint256 _tokenId)
        external
        view
        returns (address payable[] memory recipients, uint256[] memory bps);

    /**
     * @notice get collection athlete address
     * @param _collectionId collectionId of NFTs
     * @return address of athlete
     */
    function getCollectionAthleteAddress(uint256 _collectionId) external view returns (address);

    /**
     * @notice get earnings share per token of collection
     * @param _collectionId collectionId of NFT
     * @return uint256 tournament share in 1e7 per token of collection
     * @return uint256 other share in 1e7 per token of collection
     */
    function getEarningsShares1e7(uint256 _collectionId) external view returns (uint256, uint256);

    /**
     * @notice check if collection exists
     * @param _collectionId collectionId of NFT
     * @return bool true if collection exists
     */
    function getCollectionExists(uint256 _collectionId) external view returns (bool);

    /**
     * @notice get tokens minted per collection
     * @param _collectionId collectionId of NFT
     * @return uint24 returns amount of minted tokens of collection
     */
    function getMintedTokensOfCollection(uint256 _collectionId) external view returns (uint24);

    function mintTo(uint256 collectionId, uint24 quantity, address recipient) external;
}
