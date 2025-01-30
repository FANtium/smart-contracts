// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC721AQueryableUpgradeable } from "erc721a-upgradeable/interfaces/IERC721AQueryableUpgradeable.sol";

enum CollectionErrorReason {
    INVALID_DATES,
    INVALID_NAME,
    INVALID_MAX_SUPPLY,
    INVALID_PRICE,
    MAX_SUPPLY_BELOW_SUPPLY,
    START_DATE_MISMATCH
}

enum MintErrorReason {
    MINT_NOT_OPENED,
    MINT_NOT_ENOUGHT_MONEY,
    MINT_PAUSED,
    MINT_BAD_ADDRESS,
    MINT_ERC20_NOT_ACCEPTED,
    COLLECTION_NOT_EXISTING,
    MINT_MAX_SUPPLY_REACH,
    MINT_ZERO_QUANTITY
}

struct FootballCollection {
    string name;
    uint256 priceUSD; // in USD (decimals = 0)
    uint256 supply; // current number of tokens of this collection in circulation
    uint256 maxSupply; // max number of tokens of this collection
    uint256 startDate; // Start date of the mint
    uint256 closeDate; // End date of the mint
    bool isPaused; // is  mint collection paused
    address team; // team treasury address
}

struct FootballCollectionData {
    string name;
    uint256 priceUSD; // in USD (decimals = 0)
    uint256 maxSupply; // max number of tokens of this collection
    uint256 startDate; // Start date of the mint
    uint256 closeDate; // End date of the mint
    bool isPaused; // is  mint collection paused
    address team; // team treasury address
}

interface IFootballTokenV1 is IERC721AQueryableUpgradeable {
    // ========================================================================
    // Events
    // ========================================================================
    event CollectionCreated(uint256 indexed collectionId, FootballCollection collection);
    event CollectionUpdated(uint256 indexed collectionId, FootballCollection collection);
    event TokensMinted(uint256 indexed collectionId, address indexed recipient, uint256[] tokens);
    event TreasuryUpdated(address oldAddress, address newAddress);
    event CollectionPausedUpdate(uint256 indexed collectionId, bool isPaused);

    // ========================================================================
    // Errors
    // ========================================================================

    error InvalidCollectionData(CollectionErrorReason errorReason);
    error MintError(MintErrorReason errorReason);

    // ========================================================================
    // Public Methods
    // ========================================================================
    function initialize(addres admin) external;
    function pause() external;
    function unpause() external;
    function tokenCollection(uint256 tokenId) external view returns (FootballCollection memory);
    function mintTo(uint256 collectionId, uint256 quantity, address recipient, address paymentToken) external;
    function setAcceptedTokens(address[] calldata tokens, bool accepted) external;
    function createCollection(FootballCollectionData memory collection) external;
    function updateCollection(uint256 collectionId, FootballCollectionData calldata collection) external;
    function setPauseCollection(uint256 collectionId, bool isPaused) external;
    function setTreasury(address newTreasury) external;
}
