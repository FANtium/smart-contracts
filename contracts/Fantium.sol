// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Fantium is ERC721, Ownable {

    using Strings for uint256;

    uint256 constant ONE_MILLION = 1_000_000;

    // generic platform event fields
    bytes32 constant FIELD_NEXT_COLLECTION_ID = "nextCollectionId";
    bytes32 constant FIELD_FANTIUM_PRIMARY_MARKET_ROYALTY_PERCENTAGE =
        "fantium primary royalty %";
    bytes32 constant FIELD_FANTIUM_SECONDARY_MARKET_ROYALTY_BPS =
        "fantium secondary royalty BPS";
    bytes32 constant FIELD_FANTIUM_PRIMARY_ADDRESS =
        "fantium primary sale address";
    bytes32 constant FIELD_FANTIUM_SECONDARY_ADDRESS =
        "fantium secondary sale address";

    // generic collection event fields
    bytes32 constant FIELD_COLLECTION_CREATED = "created";
    bytes32 constant FIELD_COLLECTION_NAME = "name";
    bytes32 constant FIELD_COLLECTION_ATHLETE_NAME = "name";
    bytes32 constant FIELD_COLLECTION_ATHLETE_ADDRESS = "athlete address";
    bytes32 constant FIELD_COLLECTION_PAUSED = "paused";
    bytes32 constant FIELD_COLLECTION_PRICE = "price";
    bytes32 constant FIELD_COLLECTION_MAX_INVOCATIONS = "max invocations";
    bytes32 constant FIELD_COLLECTION_PRIMARY_MARKET_ROYALTY_PERCENTAGE =
        "collection primary sale %";
    bytes32 constant FIELD_COLLECTION_SECONDARY_MARKET_ROYALTY_PERCENTAGE =
        "collection secondary sale %";
    bytes32 constant FIELD_COLLECTION_BASE_URI = "collection base uri";

    struct Collection {
        uint24 invocations;
        uint24 maxInvocations;
        uint256 priceInWei;
        bool paused;
        string name;
        string athleteName;
        string collectionBaseURI;
        address payable athleteAddress;
        // packed uint: max of 100, max uint8 = 255
        uint8 athletePrimarySalesPercentage;
        // packed uint: max of 100, max uint8 = 255
        uint8 athleteSecondarySalesPercentage;
    }

    mapping(uint256 => Collection) public collections;

    /// FANtium's payment address for all primary sales revenues (packed)
    address payable public FANtiumPrimarySalesAddress;
    /// Percentage of primary sales revenue allocated to FANtium (packed)
    /// packed uint: max of 25, max uint8 = 255
    uint8 private _FANtiumPrimarySalesPercentage = 10;

    /// FANtium payment address for all secondary sales royalty revenues
    address payable public FANtiumSecondarySalesAddress;
    /// Basis Points of secondary sales royalties allocated to FANtium
    uint256 public FANtiumSecondarySalesBPS = 250;

    /// next collection ID to be created
    uint248 private _nextCollectionId;

    //////////////////////////////////////////////////////////////
    ////////////////////// MODIFIERS /////////////////////////////
    //////////////////////////////////////////////////////////////

    modifier onlyAthlete(uint256 _collectionId) {
        require(
            msg.sender == collections[_collectionId].athleteAddress || msg.sender == owner(),
            "Only athlete or admin"
        );
        _;
    }


    //////////////////////////////////////////////////////////////
    ///////////////////// CONSTRUCTOR ////////////////////////////
    //////////////////////////////////////////////////////////////

    /**
     * @notice Initializes contract.
     * @param _tokenName Name of token.
     * @param _tokenSymbol Token symbol.
     * @param _startingCollectionId The initial next collection ID.
     * @dev _startingcollectionId should be set to a value much, much less than
     * max(uint248) to avoid overflow when adding to it.
     */
    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _startingCollectionId
    ) ERC721(_tokenName, _tokenSymbol) {
        _nextCollectionId = uint248(_startingCollectionId);
        emit PlatformUpdated(FIELD_NEXT_COLLECTION_ID);
    }


    //////////////////////////////////////////////////////////////
    //////////////////////// TOKEN ///////////////////////////////
    //////////////////////////////////////////////////////////////

    /**
     * @notice Mints a token from collection `_collectionId` and sets the
     * token's owner to `_to`.
     * @param _to Address to be the minted token's owner.
     * @param _collectionId collection ID to mint a token on.
     */
    function mint(
        address _to,
        uint256 _collectionId,
    ) external returns (uint256 _tokenId) {
        // CHECKS
        Collection storage collection = collections[_collectionId];
        // load invocations into memory
        uint24 invocationsBefore = collection.invocations;
        uint24 invocationsAfter;
        unchecked {
            // invocationsBefore guaranteed <= maxInvocations <= 1_000_000,
            // 1_000_000 << max uint24, so no possible overflow
            invocationsAfter = invocationsBefore + 1;
        }
        uint24 maxInvocations = collection.maxInvocations;

        require(
            invocationsBefore < maxInvocations,
            "Must not exceed max invocations"
        );
        require(!collection.paused, "Purchases are paused.");

        // EFFECTS
        // increment project's invocations
        collection.invocations = invocationsAfter;
        uint256 thisTokenId;
        unchecked {
            // invocationsBefore is uint24 << max uint256. In production use,
            // _projectId * ONE_MILLION must be << max uint256, otherwise
            // tokenIdToProjectId function become invalid.
            // Therefore, no risk of overflow
            thisTokenId = (_collectionId * ONE_MILLION) + invocationsBefore;
        }

        // INTERACTIONS
        _mint(_to, thisTokenId);

        // Do not need to also log `collectionId` in event, as the `collectionId` for
        // a given token can be derived from the `tokenId` with:
        //   collectionId = collectionId / 1_000_000
        emit Mint(_to, thisTokenId);

        return thisTokenId;
    }

    /**
     * @notice Gets token URI for token ID `_tokenId`.
     * @dev token URIs are the concatenation of the project base URI and the
     * token ID.
     */
    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        string memory _collectionBaseURI = collections[_tokenId / ONE_MILLION]
            .collectionBaseURI;
        return string.concat(_collectionBaseURI, _tokenId.toString());
    }


    //////////////////////////////////////////////////////////////
    ////////////////////// COLLECTIONS ///////////////////////////
    //////////////////////////////////////////////////////////////

    /**
     * @notice Adds new token `_tokenName` by `_athleteAddress`.
     * @param _collectionName Token name.
     * @param _athleteAddress Athlete's address.
     * @param _maxInvocations Maximum number of times the token can be minted.
     * @param _priceInWei Price of the token.
     */
    function addCollection(
        string memory _collectionName,
        string memory _athleteName,
        string memory _collectionBaseURI,
        address payable _athleteAddress,
        uint24 _maxInvocations,
        uint256 _priceInWei,
        uint8 _athletePrimarySalesPercentage,
        uint8 _athleteSecondarySalesPercentage
    ) public onlyOwner {
        uint256 collectionId = _nextCollectionId;
        collections[collectionId].name = _collectionName;
        collections[collectionId].athleteName = _athleteName;
        collections[collectionId].collectionBaseURI = _collectionBaseURI;
        collections[collectionId].athleteAddress = _athleteAddress;
        collections[collectionId].paused = true;
        collections[collectionId].priceInWei = _priceInWei;
        collections[collectionId].maxInvocations = _maxInvocations;
        collections[collectionId].athleteAddress = _athleteAddress;
        collections[collectionId]
            .athletePrimarySalesPercentage = _athletePrimarySalesPercentage;
        collections[collectionId]
            .athleteSecondarySalesPercentage = _athleteSecondarySalesPercentage;

        _nextCollectionId = uint248(collectionId) + 1;
        emit CollectionUpdated(collectionId, FIELD_COLLECTION_CREATED);
    }

    /**
     * @notice Updates name of collection `_collectionId` to be `_collectionName`.
     */
    function updateCollectionName(
        uint256 _collectionId,
        string memory _collectionName
    ) external onlyOwner {
        collections[_collectionId].name = _collectionName;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_NAME);
    }

    /**
     * @notice Updates athlete of collection `_collectionId` to `_athleteAddress`.
     */
    function updateCollectionAthleteAddress(
        uint256 _collectionId,
        address payable _athleteAddress
    ) external onlyOwner {
        collections[_collectionId].athleteAddress = _athleteAddress;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_ATHLETE_ADDRESS);
    }

    /**
     * @notice Toggles paused state of collection `_collectionId`.
     */
    function toggleCollectionIsPaused(uint256 _collectionId)
        external
        onlyAthlete(_collectionId)
    {
        collections[_collectionId].paused = !collections[_collectionId].paused;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_PAUSED);
    }

    /**
     * @notice Updates price of collection `_collectionId` to be `_priceInWei`.
     */
    function updateCollectionPrice(uint256 _collectionId, uint256 _priceInWei)
        external
        onlyOwner
    {
        collections[_collectionId].priceInWei = _priceInWei;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_PRICE);
    }

    /**
     * @notice Updates collection maxInvocations for collection `_collectionId` to be
     * `_maxInvocations`.
     */

    function updateCollectionMaxInvocations(
        uint256 _collectionId,
        uint24 _maxInvocations
    ) external onlyOwner {
        collections[_collectionId].maxInvocations = _maxInvocations;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_MAX_INVOCATIONS);
    }

    /**
     * @notice Updates collection baseURI for collection `_collectionId` to be
     * `_collectionBaseURI`.
     */
    function updateCollectionBaseURI(
        uint256 _collectionId,
        string memory _collectionBaseURI
    ) external onlyOwner {
        collections[_collectionId].collectionBaseURI = _collectionBaseURI;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_BASE_URI);
    }

    /**
     * @notice Updates Athlete name for collection `_collectionId` to be
     * `_collectionAthleteName`.
     */
    function updateCollectionAthleteName(
        uint256 _collectionId,
        string memory _collectionAthleteName
    ) external onlyOwner {
        collections[_collectionId].athleteName = _collectionAthleteName;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_ATHLETE_NAME);
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
     * or equal to 95 percent.
     */
    function updateCollectionAthletePrimaryMarketRoyaltyPercentage(
        uint256 _collectionId,
        uint256 _primaryMarketRoyalty
    ) external onlyOwner {
        require(_primaryMarketRoyalty <= 95, "Max of 95%");
        collections[_collectionId].athletePrimarySalesPercentage = uint8(
            _primaryMarketRoyalty
        );
        emit CollectionUpdated(
            _collectionId,
            FIELD_COLLECTION_PRIMARY_MARKET_ROYALTY_PERCENTAGE
        );
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
    function updateCollectionAthleteSecondaryMarketRoyaltyPercentage(
        uint256 _collectionId,
        uint256 _secondMarketRoyalty
    ) external onlyOwner {
        require(_secondMarketRoyalty <= 95, "Max of 95%");
        collections[_collectionId].athleteSecondarySalesPercentage = uint8(
            _secondMarketRoyalty
        );
        emit CollectionUpdated(
            _collectionId,
            FIELD_COLLECTION_SECONDARY_MARKET_ROYALTY_PERCENTAGE
        );
    }


    //////////////////////////////////////////////////////////////
    //////////////////////// PLATFROM ////////////////////////////
    //////////////////////////////////////////////////////////////

    /**
     * @notice Updates the platform primary market royalties to be
     * `_primaryMarketRoyalty` percent.
     * @param _primaryMarketRoyalty Percent of primary sales revenue that will
     * be sent to the platform. This must be less than
     * or equal to 95 percent.
     */
    function updatePlatformPrimaryMarketRoyaltyPercentage(
        uint256 _primaryMarketRoyalty
    ) external onlyOwner {
        require(_primaryMarketRoyalty <= 95, "Max of 95%");
        _FANtiumPrimarySalesPercentage = uint8(_primaryMarketRoyalty);
        emit PlatformUpdated(FIELD_FANTIUM_PRIMARY_MARKET_ROYALTY_PERCENTAGE);
    }

    /**
     * @notice Updates the platform secondary market royalties to be
     * `_secondMarketRoyaltyBPS` percent.
     * @param _secondMarketRoyaltyBPS Percent of secondary sales revenue that will
     * be sent to the platform. This must be less than
     * or equal to 95 percent.
     */
    function updatePlatformSecondaryMarketRoyaltyBPS(
        uint256 _secondMarketRoyaltyBPS
    ) external onlyOwner {
        require(_secondMarketRoyaltyBPS <= 9500, "Max of 95%");
        FANtiumSecondarySalesBPS = uint256(_secondMarketRoyaltyBPS);
        emit PlatformUpdated(FIELD_FANTIUM_SECONDARY_MARKET_ROYALTY_BPS);
    }

    /**
     * @notice Updates the platform address to be `_platformAddress`.
     */
    function updateFANtiumPrimarySaleAddress(
        address payable _FANtiumPrimarySalesAddress
    ) external onlyOwner {
        FANtiumPrimarySalesAddress = _FANtiumPrimarySalesAddress;
        emit PlatformUpdated(FIELD_FANTIUM_PRIMARY_ADDRESS);
    }

    // update fantium secondary sales address
    function updateFANtiumSecondarySaleAddress(
        address payable _FANtiumSecondarySalesAddress
    ) external onlyOwner {
        FANtiumSecondarySalesAddress = _FANtiumSecondarySalesAddress;
        emit PlatformUpdated(FIELD_FANTIUM_SECONDARY_ADDRESS);
    }


    //////////////////////////////////////////////////////////////
    ///////////////////////// EVENTS /////////////////////////////
    //////////////////////////////////////////////////////////////

    /**
     * @notice Token ID `_tokenId` minted to `_to`.
     */
    event Mint(address indexed _to, uint256 indexed _tokenId);

    /**
     * @notice Collection ID `_collectionId` updated on bytes32-encoded field
     * `_update`.
     */
    event CollectionUpdated(
        uint256 indexed _collectionId,
        bytes32 indexed _update
    );

    /**
     * @notice Platform updated on bytes32-encoded field `_field`.
     */
    event PlatformUpdated(bytes32 indexed _field);
}
