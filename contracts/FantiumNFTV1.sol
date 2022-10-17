// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Open Zeppelin libraries for controlling upgradability and access.
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

/**
 * @title FANtium ERC721 contract V1.
 * @author MTX stuido AG.
 */

contract FantiumNFTV1 is
    ERC721Upgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    using Strings for uint256;

    address[] public kycedAddresses;
    mapping(uint256 => address) internal _owners;
    mapping(uint256 => Collection) public collections;
    mapping(uint256 => address[]) public collectionIdToAllowList;
    mapping(string => Tier) public tiers;
    bool public tiersSet;

    // ACM
    address public kycManagerAddress;
    address public collectionsManagerAddress;

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
    bytes32 constant FIELD_COLLECTION_TIER = "collection tier";

    /// FANtium's payment address for all primary sales revenues (packed)
    address payable public fantiumPrimarySalesAddress;
    bool public fantiumPrimarySalesAddressSet;

    /// FANtium payment address for all secondary sales royalty revenues
    address payable public fantiumSecondarySalesAddress;
    bool public fantiumSecondarySalesAddressSet;

    /// Basis Points of secondary sales royalties allocated to FANtium
    uint256 public fantiumSecondarySalesBPS;
    bool public fantiumSecondarySalesBPSSet;

    /// next collection ID to be created
    uint256 private nextCollectionId;
    bool public nextCollectionIdSet;

    struct Collection {
        uint24 invocations;
        Tier tier;
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

    struct Tier {
        string name;
        uint256 priceInWei;
        uint24 maxInvocations;
        uint8 tournamentEarningPercentage;
    }

    /*//////////////////////////////////////////////////////////////
                                 MODIFERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAthlete(uint256 _collectionId) {
        require(
            msg.sender == collections[_collectionId].athleteAddress ||
                msg.sender == owner(),
            "Only athlete or admin"
        );
        _;
    }

    modifier onlyValidTier(string memory _tierName) {
        require(bytes(tiers[_tierName].name).length > 0, "Invalid tier");
        _;
    }

    modifier onlyKycManager() {
        require(
            msg.sender == kycManagerAddress || msg.sender == owner(),
            "Only KYC updater"
        );
        _;
    }

    modifier onlyCollectionsManager() {
        require(
            msg.sender == collectionsManagerAddress || msg.sender == owner(),
            "Only collection updater"
        );
        _;
    }

    modifier onlyInitializedContract() {
        require(
            fantiumPrimarySalesAddressSet,
            "FANtium primary address is not initialized"
        );
        require(
            fantiumSecondarySalesAddressSet,
            "FANtium secondary address is not initialized"
        );
        require(
            fantiumSecondarySalesBPSSet,
            "FANtium secondary BPS is not initialized"
        );
        require(nextCollectionIdSet, "Next collection ID is not initialized");
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            UUPS UPGRADEABLE
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes contract.
     * @param _tokenName Name of token.
     * @param _tokenSymbol Token symbol.
     * @param _startingCollectionId The initial next collection ID.
     * @dev _startingcollectionId should be set to a value much, much less than
     * max(uint248) to avoid overflow when adding to it.
     */
    ///@dev no constructor in upgradable contracts. Instead we have initializers
    function initialize(string memory _tokenName, string memory _tokenSymbol)
        public
        initializer
    {
        ///@dev as there is no constructor, we need to initialise the OwnableUpgradeable explicitly
        __ERC721_init(_tokenName, _tokenSymbol);
        __Ownable_init();
        __UUPSUpgradeable_init();

        emit PlatformUpdated(FIELD_NEXT_COLLECTION_ID);
    }

    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                                 KYC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add address to KYC list.
     * @param _address address to be added to KYC list.
     */
    function addAddressToKYC(address _address) external onlyKycManager {
        kycedAddresses.push(_address);
        emit AddressAddedToKYC(_address);
    }

    /**
     * @notice Remove address from KYC list.
     * @param _address address to be removed from KYC list.
     */
    function removeAddressFromKYC(address _address) external onlyKycManager {
        for (uint256 i = 0; i < kycedAddresses.length; i++) {
            if (kycedAddresses[i] == _address) {
                kycedAddresses[i] = kycedAddresses[kycedAddresses.length - 1];
                kycedAddresses.pop();
                emit AddressRemovedFromKYC(_address);
                return;
            }
        }
    }

    /**
     * @notice Check if address is KYCed.
     * @param _address address to be checked.
     * @return isKYCed true if address is KYCed.
     */
    function isAddressKYCed(address _address) public view returns (bool) {
        for (uint256 i = 0; i < kycedAddresses.length; i++) {
            if (kycedAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                                 Allow List
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add address to allow list.
     * @param _collectionId collection ID.
     * @param _address address to be added to allow list.
     */
    function addAddressToAllowList(uint256 _collectionId, address _address)
        external
        onlyOwner
    {
        collectionIdToAllowList[_collectionId].push(_address);
        emit AddressAddedToAllowList(_collectionId, _address);
    }

    /**
     * @notice Remove address from allow list.
     * @param _collectionId collection ID.
     * @param _address address to be removed from allow list.
     */
    function removeAddressFromAllowList(uint256 _collectionId, address _address)
        external
        onlyOwner
    {
        for (
            uint256 i = 0;
            i < collectionIdToAllowList[_collectionId].length;
            i++
        ) {
            if (collectionIdToAllowList[_collectionId][i] == _address) {
                collectionIdToAllowList[_collectionId][
                    i
                ] = collectionIdToAllowList[_collectionId][
                    collectionIdToAllowList[_collectionId].length - 1
                ];
                collectionIdToAllowList[_collectionId].pop();
                emit AddressRemovedFromAllowList(_collectionId, _address);
                return;
            }
        }
    }

    /**
     * @notice Check if address is on allow list.
     * @param _collectionId collection ID.
     * @param _address address to be checked.
     * @return isOnAllowList true if address is on allow list.
     */
    function isAddressOnAllowList(uint256 _collectionId, address _address)
        public
        view
        returns (bool)
    {
        if (_address == owner()) {
            return true;
        }
        for (
            uint256 i = 0;
            i < collectionIdToAllowList[_collectionId].length;
            i++
        ) {
            if (collectionIdToAllowList[_collectionId][i] == _address) {
                return true;
            }
        }
        return false;
    }

    /*//////////////////////////////////////////////////////////////
                                 MINTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints a token from collection `_collectionId` and sets the
     * token's owner to `_to`.
     * @param _to Address to be the minted token's owner.
     * @param _collectionId collection ID to mint a token on.
     */
    function mint(address _to, uint256 _collectionId)
        public
        payable
        returns (uint256 _tokenId)
    {
        // CHECKS
        require(isAddressKYCed(msg.sender), "Address not KYCed");

        Collection storage collection = collections[_collectionId];

        if (!isAddressOnAllowList(_collectionId, msg.sender)) {
            require(!collection.paused, "Purchases are paused.");
        }

        // load invocations into memory
        uint24 invocationsBefore = collection.invocations;
        uint24 invocationsAfter;
        unchecked {
            // invocationsBefore guaranteed <= maxInvocations <= 1_000_000,
            // 1_000_000 << max uint24, so no possible overflow
            invocationsAfter = invocationsBefore + 1;
        }
        uint24 maxInvocations = collection.tier.maxInvocations;
        require(
            invocationsBefore < maxInvocations,
            "Must not exceed max invocations"
        );

        // load price of token into memory
        uint256 _pricePerTokenInWei = collection.tier.priceInWei;
        // check if msg.value is more or equal to price of token
        require(
            msg.value >= _pricePerTokenInWei,
            "Must send minimum value to mint!"
        );

        // EFFECTS
        // increment collection's invocations
        collection.invocations = invocationsAfter;
        uint256 thisTokenId;
        unchecked {
            // invocationsBefore is uint24 << max uint256. In production use,
            // _collectionId * ONE_MILLION must be << max uint256, otherwise
            // tokenIdTocollectionId function become invalid.
            // Therefore, no risk of overflow
            thisTokenId = (_collectionId * ONE_MILLION) + invocationsBefore;
        }

        // INTERACTIONS
        _mint(_to, thisTokenId);
        _splitFundsETH(_collectionId, _pricePerTokenInWei);

        emit Mint(_to, thisTokenId);

        return thisTokenId;
    }

    /**
     * @dev splits ETH funds between sender (if refund),
     * FANtium, and athlete for a token purchased on
     * collection `_collectionId`.
     */
    function _splitFundsETH(uint256 _collectionId, uint256 _pricePerTokenInWei)
        internal
    {
        if (msg.value > 0) {
            bool success_;
            // send refund to sender
            uint256 refund = msg.value - _pricePerTokenInWei;
            if (refund > 0) {
                (success_, ) = msg.sender.call{value: refund}("");
                require(success_, "Refund failed");
            }
            // split remaining funds between FANtium and athlete
            (
                uint256 fantiumRevenue_,
                address payable fantiumAddress_,
                uint256 athleteRevenue_,
                address payable athleteAddress_
            ) = getPrimaryRevenueSplits(_collectionId, _pricePerTokenInWei);
            // FANtium payment
            if (fantiumRevenue_ > 0) {
                (success_, ) = fantiumAddress_.call{value: fantiumRevenue_}("");
                require(success_, "FANtium payment failed");
            }
            // athlete payment
            if (athleteRevenue_ > 0) {
                (success_, ) = athleteAddress_.call{value: athleteRevenue_}("");
                require(success_, "Artist payment failed");
            }
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
    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        string memory _collectionBaseURI = collections[_tokenId / ONE_MILLION]
            .collectionBaseURI;
        return
            string(
                bytes.concat(
                    bytes(_collectionBaseURI),
                    bytes(_tokenId.toString())
                )
            );
    }

    /**
     * @notice Returns true if the token is minted.
     */
    function exists(uint256 _tokenId) public view returns (bool) {
        return _owners[_tokenId] != address(0);
    }

    /*//////////////////////////////////////////////////////////////
                            MANAGER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds new collection.
     * @param _collectionName Name of the collection.
     * @param _athleteName Name of the athlete.
     * @param _collectionBaseURI Base URI of the collection.
     * @param _athleteAddress Address of the athlete.
     * @param _athletePrimarySalesPercentage Primary sales percentage of the athlete.
     * @param _athleteSecondarySalesPercentage Secondary sales percentage of the athlete.
     * @param _tierName Name of the tier.
     */
    function addCollection(
        string memory _collectionName,
        string memory _athleteName,
        string memory _collectionBaseURI,
        address payable _athleteAddress,
        uint8 _athletePrimarySalesPercentage,
        uint8 _athleteSecondarySalesPercentage,
        string memory _tierName
    ) public onlyCollectionsManager onlyInitializedContract onlyValidTier(_tierName) {
        uint256 collectionId = nextCollectionId;
        collections[collectionId].name = _collectionName;
        collections[collectionId].athleteName = _athleteName;
        collections[collectionId].collectionBaseURI = _collectionBaseURI;
        collections[collectionId].athleteAddress = _athleteAddress;
        collections[collectionId].paused = true;
        collections[collectionId].athleteAddress = _athleteAddress;
        collections[collectionId]
            .athletePrimarySalesPercentage = _athletePrimarySalesPercentage;
        collections[collectionId]
            .athleteSecondarySalesPercentage = _athleteSecondarySalesPercentage;
        collections[collectionId].tier = tiers[_tierName];

        nextCollectionId = collectionId + 1;
        emit CollectionUpdated(collectionId, FIELD_COLLECTION_CREATED);
    }

    /**
     * @notice Updates name of collection `_collectionId` to be `_collectionName`.
     */
    function updateCollectionName(
        uint256 _collectionId,
        string memory _collectionName
    ) external onlyCollectionsManager {
        collections[_collectionId].name = _collectionName;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_NAME);
    }

    /**
     * @notice Updates athlete of collection `_collectionId` to `_athleteAddress`.
     */
    function updateCollectionAthleteAddress(
        uint256 _collectionId,
        address payable _athleteAddress
    ) external onlyCollectionsManager {
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
        onlyCollectionsManager
    {
        collections[_collectionId].tier.priceInWei = _priceInWei;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_PRICE);
    }

    /**
     * @notice Updates collection maxInvocations for collection `_collectionId` to be
     * `_maxInvocations`.
     */
    function updateCollectionMaxInvocations(
        uint256 _collectionId,
        uint24 _maxInvocations
    ) external onlyCollectionsManager {
        collections[_collectionId].tier.maxInvocations = _maxInvocations;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_MAX_INVOCATIONS);
    }

    /**
     * @notice Update Collection tier for collection `_collectionId` to be `_tierName`.
     */
    function updateCollectionTier(uint256 _collectionId, string memory tierName)
        external
        onlyCollectionsManager
        onlyValidTier(tierName)
    {
        collections[_collectionId].tier = tiers[tierName];
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_TIER);
    }

    /**
     * @notice Updates collection baseURI for collection `_collectionId` to be
     * `_collectionBaseURI`.
     */
    function updateCollectionBaseURI(
        uint256 _collectionId,
        string memory _collectionBaseURI
    ) external onlyCollectionsManager {
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
    ) external onlyCollectionsManager {
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
    ) external onlyCollectionsManager {
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
    ) external onlyCollectionsManager {
        require(_secondMarketRoyalty <= 95, "Max of 95%");
        collections[_collectionId].athleteSecondarySalesPercentage = uint8(
            _secondMarketRoyalty
        );
        emit CollectionUpdated(
            _collectionId,
            FIELD_COLLECTION_SECONDARY_MARKET_ROYALTY_PERCENTAGE
        );
    }

    /*///////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the platform secondary market royalties to be
     * `_secondMarketRoyaltyBPS` percent.
     * @param _fantiumSecondarySalesBPS Percent of secondary sales revenue that will
     * be sent to the platform. This must be less than
     * or equal to 95 percent.
     */
    function updateFantiumSecondaryMarketRoyaltyBPS(
        uint256 _fantiumSecondarySalesBPS
    ) external onlyOwner {
        require(_fantiumSecondarySalesBPS <= 9500, "Max of 95%");
        fantiumSecondarySalesBPS = uint256(_fantiumSecondarySalesBPS);
        fantiumSecondarySalesBPSSet = true;
        emit PlatformUpdated(FIELD_FANTIUM_SECONDARY_MARKET_ROYALTY_BPS);
    }

    /**
     * @notice Updates the platform address to be `_fantiumPrimarySalesAddress`.
     */
    function updateFantiumPrimarySaleAddress(
        address payable _fantiumPrimarySalesAddress
    ) external onlyOwner {
        fantiumPrimarySalesAddress = _fantiumPrimarySalesAddress;
        fantiumPrimarySalesAddressSet = true;
        emit PlatformUpdated(FIELD_FANTIUM_PRIMARY_ADDRESS);
    }

    /**
     * @notice Updates the FANtium's secondary sales'
     * address to be `_fantiumSecondarySalesAddress`.
     */
    // update fantium secondary sales address
    function updateFantiumSecondarySaleAddress(
        address payable _fantiumSecondarySalesAddress
    ) external onlyOwner {
        fantiumSecondarySalesAddress = _fantiumSecondarySalesAddress;
        fantiumSecondarySalesAddressSet = true;
        emit PlatformUpdated(FIELD_FANTIUM_SECONDARY_ADDRESS);
    }

    /**
     * @notice Updates the tier mapping for `_name` to `_tier`.
     * @param _name Name of the tier.
     * @param _priceInWei Price of the tier.
     * @param _maxInvocations Max invocations of the tier.
     * @param _tournamentEarningPercentage Tournament earnings percentage of the tier.
     */
    function updateTiers(
        string memory _name,
        uint256 _priceInWei,
        uint24 _maxInvocations,
        uint8 _tournamentEarningPercentage
    ) external onlyOwner {
        tiers[_name] = Tier(
            _name,
            _priceInWei,
            _maxInvocations,
            _tournamentEarningPercentage
        );
    }

    /**
     * @notice sets the initial collection Id to be `_nextCollectionId`.
     * @param _nextCollectionId next collection Id.
     */
    function setNextCollectionId(uint256 _nextCollectionId) external onlyOwner {
        nextCollectionId = _nextCollectionId;
        nextCollectionIdSet = true;
        //we might want to prevent this once set.
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the collection ID for token ID `_tokenId`.
     * @param _tokenId Token ID to be queried.
     * @return collectionId Collection ID for token ID `_tokenId`.
     */
    function getCollectionForTokenId(uint256 _tokenId)
        external
        view
        returns (Collection memory)
    {
        uint256 collectionId = _tokenId / ONE_MILLION;
        Collection memory collection = getCollection(collectionId);
        return collection;
    }

    // get collection for collectionId
    function getCollection(uint256 _collectionId)
        public
        view
        returns (Collection memory)
    {
        return collections[_collectionId];
    }

    // get all collection properties for collectionId
    function getCollectionData(uint256 _collectionId)
        public
        view
        returns (
            uint24 invocations,
            uint24 maxInvocations,
            uint256 priceInWei,
            bool paused,
            string memory name,
            string memory athleteName,
            string memory collectionBaseURI,
            address payable athleteAddress,
            uint8 athletePrimarySalesPercentage,
            uint8 athleteSecondarySalesPercentage,
            string memory tierName,
            uint8 tournamentEarningPercentage
        )
    {
        Collection memory collection = collections[_collectionId];
        return (
            collection.invocations,
            collection.tier.maxInvocations,
            collection.tier.priceInWei,
            collection.paused,
            collection.name,
            collection.athleteName,
            collection.collectionBaseURI,
            collection.athleteAddress,
            collection.athletePrimarySalesPercentage,
            collection.athleteSecondarySalesPercentage,
            collection.tier.name,
            collection.tier.tournamentEarningPercentage
        );
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
    function getPrimaryRevenueSplits(uint256 _collectionId, uint256 _price)
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
        Collection memory collection = collections[_collectionId];

        // calculate revenues
        athleteRevenue_ =
            (_price * uint256(collection.athletePrimarySalesPercentage)) /
            100;
        uint256 collectionFunds;
        unchecked {
            // fantiumRevenue_ is always <=25, so guaranteed to never underflow
            collectionFunds = _price - athleteRevenue_;
        }

        unchecked {
            // collectionIdToAdditionalPayeePrimarySalesPercentage is always
            // <=100, so guaranteed to never underflow
            fantiumRevenue_ = collectionFunds;
        }

        // set addresses from storage
        fantiumAddress_ = fantiumPrimarySalesAddress;
        if (athleteRevenue_ > 0) {
            athleteAddress_ = collection.athleteAddress;
        }
    }

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
        returns (
            // onlyValidTokenId(_tokenId)
            address payable[] memory recipients,
            uint256[] memory bps
        )
    {
        // initialize arrays with maximum potential length
        recipients = new address payable[](2);
        bps = new uint256[](2);

        uint256 collectionId = _tokenId / ONE_MILLION;
        Collection storage collection = collections[collectionId];
        // load values into memory
        uint256 royaltyPercentageForAthlete = collection
            .athleteSecondarySalesPercentage;
        // calculate BPS = percentage * 100
        uint256 athleteBPS = royaltyPercentageForAthlete * 100;

        uint256 fantiumBPS = fantiumSecondarySalesBPS;
        // populate arrays
        uint256 payeeCount;
        if (athleteBPS > 0) {
            recipients[payeeCount] = collection.athleteAddress;
            bps[payeeCount++] = athleteBPS;
        }
        if (fantiumBPS > 0) {
            recipients[payeeCount] = fantiumSecondarySalesAddress;
            bps[payeeCount++] = fantiumBPS;
        }

        //TODO - check if this is necessary

        // trim arrays if necessary
        // if (2 > payeeCount) {
        //     assembly {
        //         let decrease := sub(2, payeeCount)
        //         mstore(recipients, sub(mload(recipients), decrease))
        //         mstore(bps, sub(mload(bps), decrease))
        //     }
        // }
        return (recipients, bps);
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Mint(address indexed _to, uint256 indexed _tokenId);
    event CollectionUpdated(
        uint256 indexed _collectionId,
        bytes32 indexed _update
    );
    event PlatformUpdated(bytes32 indexed _field);
    event MinterUpdated(address indexed _currentMinter);
    event AddressAddedToKYC(address indexed _address);
    event AddressRemovedFromKYC(address indexed _address);
    event AddressAddedToAllowList(
        uint256 collectionId,
        address indexed _address
    );
    event AddressRemovedFromAllowList(
        uint256 collectionId,
        address indexed _address
    );
}
