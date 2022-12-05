// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title FANtium ERC721 contract V1.
 * @author MTX stuido AG.
 */

contract FantiumNFTV1 is
    Initializable,
    ERC721Upgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    DefaultOperatorFiltererUpgradeable,
    PausableUpgradeable
{
    using StringsUpgradeable for uint256;

    address public fantiumMinterAddress;
    mapping(uint256 => Collection) public collections;
    mapping(string => Tier) public tiers;
    string public baseURI;
    mapping(uint256 => mapping(address => uint256))
        public collectionIdToAllowList;
    mapping(address => bool) public kycedAddresses;

    uint256 constant ONE_MILLION = 1_000_000;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    bytes4 private constant _INTERFACE_ID_ERC2981_OVERRIDE = 0xbb3bafd6;

    /// ACM
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE =
        keccak256("PLATFORM_MANAGER_ROLE");
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");

    /// generic event fields
    bytes32 constant FIELD_FANTIUM_PRIMARY_MARKET_ROYALTY_PERCENTAGE =
        "fantium primary royalty %";
    bytes32 constant FIELD_FANTIUM_SECONDARY_MARKET_ROYALTY_BPS =
        "fantium secondary royalty BPS";
    bytes32 constant FIELD_FANTIUM_PRIMARY_ADDRESS =
        "fantium primary sale address";
    bytes32 constant FIELD_FANTIUM_SECONDARY_ADDRESS =
        "fantium secondary sale address";
    bytes32 constant FIELD_COLLECTION_CREATED = "created";
    bytes32 constant FIELD_COLLECTION_NAME = "name";
    bytes32 constant FIELD_COLLECTION_ATHLETE_NAME = "name";
    bytes32 constant FIELD_COLLECTION_ATHLETE_ADDRESS = "athlete address";
    bytes32 constant FIELD_COLLECTION_PAUSED = "isMintingPaused";
    bytes32 constant FIELD_COLLECTION_PRICE = "price";
    bytes32 constant FIELD_COLLECTION_MAX_INVOCATIONS = "max invocations";
    bytes32 constant FIELD_COLLECTION_PRIMARY_MARKET_ROYALTY_PERCENTAGE =
        "collection primary sale %";
    bytes32 constant FIELD_COLLECTION_SECONDARY_MARKET_ROYALTY_PERCENTAGE =
        "collection secondary sale %";
    bytes32 constant FIELD_COLLECTION_BASE_URI = "collection base uri";
    bytes32 constant FIELD_COLLECTION_TIER = "collection tier";
    bytes32 constant FILED_FANTIUM_BASE_URI = "fantium base uri";
    bytes32 constant FIELD_FANTIUM_MINTER_ADDRESS = "fantium minter address";

    /// FANtium's payment address for all primary sales revenues (packed)
    address payable public fantiumPrimarySalesAddress;

    /// FANtium's payment address for all secondary sales royalty revenues
    address payable public fantiumSecondarySalesAddress;

    /// Basis Points of secondary sales royalties allocated to FANtium
    uint256 public fantiumSecondarySalesBPS;

    /// next collection ID to be created
    uint256 private nextCollectionId;

    struct Tier {
        string name;
        uint256 priceInWei;
        uint24 maxInvocations;
        uint8 tournamentEarningPercentage;
    }

    struct Collection {
        uint24 invocations;
        string tierName;
        bool exists;
        bool isMintingPaused;
        string name;
        string athleteName;
        string collectionBaseURI;
        address payable athleteAddress;
        // packed uint: max of 100, max uint8 = 255
        uint8 athletePrimarySalesPercentage;
        // packed uint: max of 100, max uint8 = 255
        uint8 athleteSecondarySalesPercentage;
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

    /*//////////////////////////////////////////////////////////////
                            INTERFACE
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControlUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return
            interfaceId == _INTERFACE_ID_ERC2981 ||
            interfaceId == _INTERFACE_ID_ERC2981_OVERRIDE ||
            super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                                 MODIFERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAthlete(uint256 _collectionId) {
        require(
            msg.sender == collections[_collectionId].athleteAddress ||
                hasRole(PLATFORM_MANAGER_ROLE, msg.sender),
            "Only athlete"
        );
        _;
    }

    modifier onlyValidTier(string memory _tierName) {
        require(bytes(tiers[_tierName].name).length > 0, "Invalid tier");
        _;
    }

    modifier onlyRoyaltySetContract() {
        require(
            fantiumPrimarySalesAddress != address(0),
            "FANtium primary address is not initialized"
        );
        require(
            fantiumSecondarySalesAddress != address(0),
            "FANtium secondary address is not initialized"
        );
        _;
    }

    modifier onlyValidCollectionId(uint256 _collectionId) {
        require(
            collections[_collectionId].exists == true,
            "Invalid collectionId"
        );
        _;
    }

    modifier onlyValidTokenId(uint256 _tokenId) {
        require(_exists(_tokenId), "Invalid tokenId");
        _;
    }

    modifier onlyValidAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier onlyKycManager() {
        require(hasRole(KYC_MANAGER_ROLE, msg.sender), "Only KYC updater");
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            UUPS UPGRADEABLE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes contract.
     * @param _tokenName Name of token.
     * @param _tokenSymbol Token symbol.
     * max(uint248) to avoid overflow when adding to it.
     */
    ///@dev no constructor in upgradable contracts. Instead we have initializers
    function initialize(
        string memory _tokenName,
        string memory _tokenSymbol,
        address _defaultAdmin
    ) public initializer {
        __ERC721_init(_tokenName, _tokenSymbol);
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __DefaultOperatorFilterer_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(UPGRADER_ROLE, msg.sender);

        nextCollectionId = 1;
    }

    /// @notice upgrade authorization logic
    /// @dev required by the OZ UUPS module
    /// @dev adds onlyRole(UPGRADER_ROLE) requirement
    function _authorizeUpgrade(
        address
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                                 KYC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add address to KYC list.
     * @param _address address to be added to KYC list.
     */
    function addAddressToKYC(
        address _address
    ) external whenNotPaused onlyKycManager {
        kycedAddresses[_address] = true;
        emit AddressAddedToKYC(_address);
    }

    /**
     * @notice Remove address from KYC list.
     * @param _address address to be removed from KYC list.
     */
    function removeAddressFromKYC(
        address _address
    ) external whenNotPaused onlyKycManager {
        kycedAddresses[_address] = false;
        emit AddressRemovedFromKYC(_address);
    }

    /**
     * @notice Check if address is KYCed.
     * @param _address address to be checked.
     * @return isKYCed true if address is KYCed.
     */
    function isAddressKYCed(address _address) public view returns (bool) {
        return kycedAddresses[_address];
    }

    /*//////////////////////////////////////////////////////////////
                            ALLOW LIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add address to allow list.
     * @param _collectionId collection ID.
     * @param _address address to be added to allow list.
     * @param _allocation allocation to the address.
     */
    function addAddressToAllowListWithAllocation(
        uint256 _collectionId,
        address _address,
        uint256 _allocation
    ) public whenNotPaused onlyRole(PLATFORM_MANAGER_ROLE) {
        collectionIdToAllowList[_collectionId][_address] = _allocation;
        emit AddressAddedToAllowList(_collectionId, _address);
    }

    /**
     * @notice Remove address from allow list.
     * @param _collectionId collection ID.
     * @param _address address to be removed from allow list.
     */
    function reduceAllowListAllocation(
        uint256 _collectionId,
        address _address,
        bool _completely
    ) public whenNotPaused onlyRole(PLATFORM_MANAGER_ROLE) {
        if (_completely) {
            collectionIdToAllowList[_collectionId][_address] = 0;
        } else {
            collectionIdToAllowList[_collectionId][_address]--;
        }
        emit AddressRemovedFromAllowList(_collectionId, _address);
    }

    /*//////////////////////////////////////////////////////////////
                                 MINTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints a token
     * @param _collectionId Collection ID.
     */
    function mint(uint256 _collectionId) public payable whenNotPaused {
        // CHECKS
        require(isAddressKYCed(msg.sender), "Address is not KYCed");
        Collection storage collection = collections[_collectionId];
        require(collection.exists, "Collection does not exist");
        if (collection.isMintingPaused) {
            // if minting is paused, require address to be on allowlist
            require(
                collectionIdToAllowList[_collectionId][msg.sender] > 0,
                "Minting is paused"
            );
        }
        Tier storage tier = tiers[collection.tierName];
        require(
            collection.invocations < tier.maxInvocations,
            "Max invocations reached"
        );
        require(tier.priceInWei <= msg.value, "Incorrect amount sent");

        uint256 tokenId = (_collectionId * ONE_MILLION) +
            collection.invocations;

        // EFFECTS
        collection.invocations++;
        if (collection.isMintingPaused) {
            collectionIdToAllowList[_collectionId][msg.sender]--;
        }

        // INTERACTIONS
        _mint(msg.sender, tokenId);
        _splitFundsETH(_collectionId, tier.priceInWei);

        emit Mint(msg.sender, tokenId);
    }

    /**
     * @dev splits ETH funds between sender (if refund),
     * FANtium, and athlete for a token purchased on
     * collection `_collectionId`.
     */
    function _splitFundsETH(
        uint256 _collectionId,
        uint256 _pricePerTokenInWei
    ) internal {
        if (msg.value > 0) {
            // send refund to sender
            uint256 refund = msg.value - _pricePerTokenInWei;
            if (refund > 0) {
                payable(msg.sender).transfer(refund);
            }
            // split remaining funds between FANtium and athlete
            (
                uint256 fantiumRevenue_,
                address fantiumAddress_,
                uint256 athleteRevenue_,
                address athleteAddress_
            ) = getPrimaryRevenueSplits(_collectionId, _pricePerTokenInWei);
            // FANtium payment
            if (fantiumRevenue_ > 0) {
                payable(fantiumAddress_).transfer(fantiumRevenue_);
            }
            // athlete payment
            if (athleteRevenue_ > 0) {
                payable(athleteAddress_).transfer(athleteRevenue_);
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
    function tokenURI(
        uint256 _tokenId
    ) public view override onlyValidTokenId(_tokenId) returns (string memory) {
        bytes memory collectionBaseURI = bytes(
            collections[_tokenId / ONE_MILLION].collectionBaseURI
        );

        if (collectionBaseURI.length != 0) {
            return
                string(
                    bytes.concat(
                        bytes(collectionBaseURI),
                        bytes(_tokenId.toString())
                    )
                );
        }

        return string(bytes.concat(bytes(baseURI), bytes(_tokenId.toString())));
    }

    /*//////////////////////////////////////////////////////////////
                        COLLECTION FUNCTIONS
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
    )
        external
        whenNotPaused
        onlyRole(PLATFORM_MANAGER_ROLE)
        onlyRoyaltySetContract
        onlyValidTier(_tierName)
        onlyValidAddress(_athleteAddress)
    {
        uint256 collectionId = nextCollectionId;
        collections[collectionId].exists = true;
        collections[collectionId].name = _collectionName;
        collections[collectionId].athleteName = _athleteName;
        collections[collectionId].collectionBaseURI = _collectionBaseURI;
        collections[collectionId].athleteAddress = _athleteAddress;
        collections[collectionId].isMintingPaused = true;
        collections[collectionId]
            .athletePrimarySalesPercentage = _athletePrimarySalesPercentage;
        collections[collectionId]
            .athleteSecondarySalesPercentage = _athleteSecondarySalesPercentage;
        collections[collectionId].tierName = _tierName;
        collections[collectionId].invocations = 1;

        nextCollectionId = collectionId + 1;
        emit CollectionUpdated(collectionId, FIELD_COLLECTION_CREATED);
    }

    /**
     * @notice Updates name of collection `_collectionId` to be `_collectionName`.
     */
    function updateCollectionName(
        uint256 _collectionId,
        string memory _collectionName
    )
        external
        whenNotPaused
        onlyValidCollectionId(_collectionId)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        collections[_collectionId].name = _collectionName;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_NAME);
    }

    /**
     * @notice Updates athlete of collection `_collectionId` to `_athleteAddress`.
     */
    function updateCollectionAthleteAddress(
        uint256 _collectionId,
        address payable _athleteAddress
    )
        external
        whenNotPaused
        onlyValidCollectionId(_collectionId)
        onlyValidAddress(_athleteAddress)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        collections[_collectionId].athleteAddress = _athleteAddress;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_ATHLETE_ADDRESS);
    }

    /**
     * @notice Toggles isMintingPaused state of collection `_collectionId`.
     */
    function toggleCollectionIsPaused(
        uint256 _collectionId
    )
        external
        whenNotPaused
        onlyValidCollectionId(_collectionId)
        onlyAthlete(_collectionId)
    {
        collections[_collectionId].isMintingPaused = !collections[_collectionId]
            .isMintingPaused;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_PAUSED);
    }

    /**
     * @notice Update Collection tier for collection `_collectionId` to be `_tierName`.
     */
    function updateCollectionTier(
        uint256 _collectionId,
        string memory _tierName
    )
        external
        whenNotPaused
        onlyValidCollectionId(_collectionId)
        onlyValidTier(_tierName)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        collections[_collectionId].tierName = _tierName;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_TIER);
    }

    /**
     * @notice Updates collection baseURI for collection `_collectionId` to be
     * `_collectionBaseURI`.
     */
    function updateCollectionBaseURI(
        uint256 _collectionId,
        string memory _collectionBaseURI
    )
        external
        whenNotPaused
        onlyValidCollectionId(_collectionId)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
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
    )
        external
        whenNotPaused
        onlyValidCollectionId(_collectionId)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
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
    )
        external
        whenNotPaused
        onlyValidCollectionId(_collectionId)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
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
    )
        external
        whenNotPaused
        onlyValidCollectionId(_collectionId)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        require(_secondMarketRoyalty <= 95, "Max of 95%");
        collections[_collectionId].athleteSecondarySalesPercentage = uint8(
            _secondMarketRoyalty
        );
        emit CollectionUpdated(
            _collectionId,
            FIELD_COLLECTION_SECONDARY_MARKET_ROYALTY_PERCENTAGE
        );
    }

    //update baseURI only platform manager
    function updateBaseURI(
        string memory _baseURI
    ) external whenNotPaused onlyRole(PLATFORM_MANAGER_ROLE) {
        baseURI = _baseURI;
        emit PlatformUpdated(FILED_FANTIUM_BASE_URI);
    }

    /*///////////////////////////////////////////////////////////////
                        PLATFORM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the platform address to be `_fantiumPrimarySalesAddress`.
     */
    function updateFantiumPrimarySaleAddress(
        address payable _fantiumPrimarySalesAddress
    )
        external
        whenNotPaused
        onlyRole(PLATFORM_MANAGER_ROLE)
        onlyValidAddress(_fantiumPrimarySalesAddress)
    {
        fantiumPrimarySalesAddress = _fantiumPrimarySalesAddress;
        emit PlatformUpdated(FIELD_FANTIUM_PRIMARY_ADDRESS);
    }

    /**
     * @notice Updates the FANtium's secondary sales'
     * address to be `_fantiumSecondarySalesAddress`.
     */
    // update fantium secondary sales address
    function updateFantiumSecondarySaleAddress(
        address payable _fantiumSecondarySalesAddress
    )
        external
        whenNotPaused
        onlyRole(PLATFORM_MANAGER_ROLE)
        onlyValidAddress(_fantiumSecondarySalesAddress)
    {
        fantiumSecondarySalesAddress = _fantiumSecondarySalesAddress;
        emit PlatformUpdated(FIELD_FANTIUM_SECONDARY_ADDRESS);
    }

    /**
     * @notice Updates the platform secondary market royalties to be
     * `_secondMarketRoyaltyBPS` percent.
     * @param _fantiumSecondarySalesBPS Percent of secondary sales revenue that will
     * be sent to the platform. This must be less than
     * or equal to 95 percent.
     */
    function updateFantiumSecondaryMarketRoyaltyBPS(
        uint256 _fantiumSecondarySalesBPS
    ) external whenNotPaused onlyRole(PLATFORM_MANAGER_ROLE) {
        require(_fantiumSecondarySalesBPS <= 9500, "Max of 95%");
        fantiumSecondarySalesBPS = uint256(_fantiumSecondarySalesBPS);
        emit PlatformUpdated(FIELD_FANTIUM_SECONDARY_MARKET_ROYALTY_BPS);
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
    ) external whenNotPaused onlyRole(PLATFORM_MANAGER_ROLE) {
        require(_maxInvocations < ONE_MILLION, "max invocation ");

        tiers[_name] = Tier(
            _name,
            _priceInWei,
            _maxInvocations,
            _tournamentEarningPercentage
        );
    }

    /**
     * @notice Update contract pause status to `_paused`.
     */

    function updateContractPaused(
        bool _paused
    ) external onlyRole(PLATFORM_MANAGER_ROLE) {
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEWS
    //////////////////////////////////////////////////////////////*/

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
    function getPrimaryRevenueSplits(
        uint256 _collectionId,
        uint256 _price
    )
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

        // fantiumRevenue_ is always <=25, so guaranteed to never underflow
        collectionFunds = _price - athleteRevenue_;

        // collectionIdToAdditionalPayeePrimarySalesPercentage is always
        // <=100, so guaranteed to never underflow
        fantiumRevenue_ = collectionFunds;

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
    function getRoyalties(
        uint256 _tokenId
    )
        external
        view
        onlyValidTokenId(_tokenId)
        returns (address payable[] memory recipients, uint256[] memory bps)
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

        return (recipients, bps);
    }

    /*//////////////////////////////////////////////////////////////
                            OS FILTER
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(
        address operator,
        bool approved
    ) public override whenNotPaused onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(
        address operator,
        uint256 tokenId
    ) public override whenNotPaused onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override whenNotPaused onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override whenNotPaused onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override whenNotPaused onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
