// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "../FantiumNFTV4.sol";
import "../utils/FantiumUserManager.sol";
import "../utils/TokenVersionUtil.sol";

/**
 * @title Claiming contract that allows payout tokens to be claimed
 * for FAN token holders.
 * @author MTX studoi AG.
 */

contract FantiumClaimingV1 is
    Initializable,
    UUPSUpgradeable,
    ERC2771ContextUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    ERC20 public payoutToken;
    FantiumNFTV4 public fantiumNFTContract;
    FantiumUserManager public fantiumUserManager;

    // mapping of distributionEvent to TokenID to claimed
    mapping(uint256 => DistributionEvent) public distributionEvents;
    mapping(uint256 => mapping(uint256 => bool))
        public distributionEventToTokenIdToClaimed;
    mapping(address => bool) public identedAddresses;

    uint256 private nextDistributionEventId;
    uint256 constant ONE_MILLION = 1_000_000;
    /// ACM
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE =
        keccak256("PLATFORM_MANAGER_ROLE");
    
    bytes32 constant FIELD_CREATED = "created";
    bytes32 constant FIELD_COLLECTIONS = "collections";
    bytes32 constant FIELD_AMOUNT = "amount";
    bytes32 constant FIELD_ADDRESSES = "addresses";
    bytes32 constant FIELD_FANTIUMFEEBPS = "fantium fee basis points";
    bytes32 constant FIELD_CLOSED = "isClosed";
    bytes32 constant FIELD_TIMESTAMPS = "start and close timestamp";


    struct DistributionEvent {
        uint256 distributionEventId;
        uint256[] collectionIds;
        address payable athleteAddress;
        uint256 amount; // currently without decimals e.g. 200.000
        uint256 distributedAmount;
        uint256 fantiumFeeBPS;
        address payable fantiumFeeAddress;
        uint256 startTime;
        uint256 closeTime;
        bool exists;
        bool closed;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Claim(uint256 amount);
    event DistributionEventUpdate(uint256 indexed _distributionEventId, bytes32 indexed _field);
    event AddDistributionEventAmount(uint256 amount);


    /*//////////////////////////////////////////////////////////////
                            MODIFERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAthlete(uint256 _distributionEventId) {
        require(
            _msgSender() ==
                distributionEvents[_distributionEventId].athleteAddress ||
                hasRole(PLATFORM_MANAGER_ROLE, _msgSender()),
            "Only athlete"
        );
        _;
    }

    modifier onlyManager() {
        require(hasRole(PLATFORM_MANAGER_ROLE, _msgSender()), "Only athlete");
        _;
    }

    modifier onlyTokenOwner(uint256 _tokenId) {
        require(
            fantiumNFTContract.ownerOf(_tokenId) == _msgSender(),
            "Invalid tokenId"
        );
        _;
    }

    modifier onlyValidAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier onlyValidDistrutionEvent(uint256 _distributionEventId) {
        require(
            distributionEvents[_distributionEventId].exists,
            "Invalid distribution event"
        );
        _;
    }

    /*///////////////////////////////////////////////////////////////
                            UUPS UPGRADEABLE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes contract.
     * max(uint248) to avoid overflow when adding to it.
     */
    ///@dev no constructor in upgradable contracts. Instead we have initializers
    function initialize(
        address _payoutToken,
        address _fantiumNFTContract,
        address _defaultAdmin
    ) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();
        payoutToken = ERC20(_payoutToken);
        fantiumNFTContract = FantiumNFTV4(_fantiumNFTContract);

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(UPGRADER_ROLE, _defaultAdmin);

        nextDistributionEventId = 1;
    }

    /// @notice upgrade authorization logic
    /// @dev required by the OZ UUPS module
    /// @dev adds onlyRole(UPGRADER_ROLE) requirement
    function _authorizeUpgrade(
        address
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address forwarder) ERC2771ContextUpgradeable(forwarder) {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if address is IDENTed.
     * @param _address address to be checked.
     * @return isIDENTed true if address is IDENTed.
     */
    function isAddressIDENT(address _address) public view returns (bool) {
        return fantiumUserManager.isAddressIDENT(_address);
    }

    /*///////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    //
    function setupDistributionEvent(
        address payable _athleteAddress,
        uint256 _amount,
        uint256 _startTime,
        uint256 _closeTime,
        uint256[] memory _collectionIds,
        address payable _fantiumAddress,
        uint256 _fantiumFeeBPS
    ) external onlyManager whenNotPaused onlyValidAddress(_athleteAddress) {
        // CHECKS
        require(
            _amount > 0,
            "FantiumClaimingV1: amount must be greater than 0"
        );
        require(
            _startTime > 0 && _closeTime > 0 && _startTime < _closeTime,
            "FantiuyarnmClaimingV1: times must be greater than 0 and close time must be greater than start time"
        );
        require(
            _collectionIds.length > 0,
            "FantiumClaimingV1: collectionIds must be greater than 0"
        );
        require(
            _amount < 1000000000,
            "FantiumClaimingV1: amount must be less than a billion"
        );

        //check if collection exists
        for (uint256 i = 0; i < _collectionIds.length; i++) {
            bool collectionExists = fantiumNFTContract
                .getCollection(_collectionIds[i])
                .exists;
            require(
                collectionExists,
                "FantiumClaimingV1: collection does not exist"
            );
        }
        // EFFECTS
        DistributionEvent memory distributionEvent;
        distributionEvent.distributionEventId = nextDistributionEventId;
        distributionEvent.amount = _amount;
        distributionEvent.collectionIds = _collectionIds;
        distributionEvent.athleteAddress = _athleteAddress;
        distributionEvent.fantiumFeeAddress = _fantiumAddress;
        distributionEvent.fantiumFeeBPS = _fantiumFeeBPS;
        distributionEvent.startTime = _startTime;
        distributionEvent.startTime = _closeTime;
        distributionEvent.exists = true;
        distributionEvent.closed = false;
        distributionEvents[nextDistributionEventId] = distributionEvent;
        emit DistributionEventUpdate(nextDistributionEventId, FIELD_CREATED);
        nextDistributionEventId++;
        
    }

    function addDistributionAmount(
        uint256 _distributionEventId,
        uint256 _amount
    ) external whenNotPaused onlyAthlete(_distributionEventId) {
        // CHECKS
        require(
            distributionEvents[_distributionEventId].exists,
            "FantiumClaimingV1: distributionEventId does not exist"
        );
        require(
            _amount == distributionEvents[_distributionEventId].amount,
            "FantiumClaimingV1: amount must be equal to distribution amount"
        );

        // EFFECTS
        distributionEvents[_distributionEventId].amount =
            distributionEvents[_distributionEventId].amount +
            _amount;
        payoutToken.transferFrom(_msgSender(), address(this), _amount);
        emit AddDistributionEventAmount(_amount);
    }

    /*///////////////////////////////////////////////////////////////
                            UPDATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateDistributionEventAmount(uint256 _id, uint256 _amount) external         
    whenNotPaused
    onlyValidDistrutionEvent(_id)
    onlyRole(PLATFORM_MANAGER_ROLE) 
    {
        distributionEvents[_id].amount = _amount;
        emit DistributionEventUpdate(_id, FIELD_AMOUNT);
    }

    function updateDistributionEventAmount(uint256 _id, uint256[] memory collectionIds) external         
    whenNotPaused
    onlyValidDistrutionEvent(_id)
    onlyRole(PLATFORM_MANAGER_ROLE) 
    {
        distributionEvents[_id].collectionIds = collectionIds;
        emit DistributionEventUpdate(_id, FIELD_COLLECTIONS);
    }

    function updateDistributionEventAddresses(uint256 _id, address payable _athleteAddress, address payable _fantiumAdress) external
    whenNotPaused
    onlyValidDistrutionEvent(_id)
    onlyRole(PLATFORM_MANAGER_ROLE) 
    {
        require(_athleteAddress != address(0) && _fantiumAdress != address(0), "FantiumClaimingV1: athlete address cannot be 0");
        distributionEvents[_id].athleteAddress = _athleteAddress;
        distributionEvents[_id].fantiumFeeAddress = _fantiumAdress;
        emit DistributionEventUpdate(_id, FIELD_ADDRESSES);
    }

    function updateDistributionEventAddresses(uint256 _id, uint256 _startTime, uint256 _closeTime) external         
    whenNotPaused
    onlyValidDistrutionEvent(_id)
    onlyRole(PLATFORM_MANAGER_ROLE) 
    {
                require(
            _startTime > 0 && _closeTime > 0 && _startTime < _closeTime,
            "FantiuyarnmClaimingV1: times must be greater than 0 and close time must be greater than start time"
        );
        distributionEvents[_id].startTime = _startTime;
        distributionEvents[_id].closeTime = _closeTime;
        emit DistributionEventUpdate(_id, FIELD_TIMESTAMPS);
    }

    function updateDistributionEventFee(uint256 _id, uint256 _feeBPS) external         
    whenNotPaused
    onlyValidDistrutionEvent(_id)
    onlyRole(PLATFORM_MANAGER_ROLE) 
    {
        require(
            _feeBPS >= 0 && _feeBPS < 10000,
            "FantiumClaimingV1: fee must be between 0 and 10000"
        );
        distributionEvents[_id].fantiumFeeBPS = _feeBPS;
        emit DistributionEventUpdate(_id, FIELD_FANTIUMFEEBPS);
    }


    /*///////////////////////////////////////////////////////////////
                            CLAIMING
    //////////////////////////////////////////////////////////////*/

    function batchClaim(
        uint256[] memory _tokenIds,
        uint256[] memory _distributionEventID
    ) external whenNotPaused {
        require(
            _tokenIds.length == _distributionEventID.length,
            "FantiumClaimingV1: Arrays must be of same length"
        );
        require(
            _tokenIds.length <= 50,
            "FantiumClaimingV1: Arrays must be of length <= 50"
        );

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            claim(_tokenIds[i], _distributionEventID[i]);
        }
    }

    function claim(
        uint256 _tokenId,
        uint256 _distributionEventId
    ) public onlyTokenOwner(_tokenId) whenNotPaused {
        // CHECKS

        //check if _msgSender() has FAN token Id
        require(
            _msgSender() == fantiumNFTContract.ownerOf(_tokenId),
            "FantiumClaimingV1: You do not own this token"
        );

        //check if _msgSender() is IDENTed
        require(
            isAddressIDENT(_msgSender()),
            "FantiumClaimingV1: You are not IDENTed"
        );

        //check if lockTime is over
        require(
            distributionEvents[_distributionEventId].startTime <
                block.timestamp,
            "FantiumClaimingV1: distribution time has not started"
        );

        //check if tokenID is valid and not to large
        require(
            _tokenId >= 1000000 && _tokenId <= 100000000000,
            "FantiumClaimingV1: invalid token id"
        );

        // check if token is from a valid collection
        // check that hasn't claimed yet for that distribution event
        (uint256 collectionOfToken, , uint256 tokenNr) = TokenVersionUtil
            .getTokenInfo(_tokenId);
        uint256 baseTokenId = collectionOfToken * 1000000 + tokenNr;
        require(
            checkTokenAllowed(
                _distributionEventId,
                collectionOfToken,
                baseTokenId
            ),
            "FantiumClaimingV1: Token already claimed or Collection not allowed"
        );

        // EFFECTS
        //set claimed to true
        distributionEventToTokenIdToClaimed[_distributionEventId][
            baseTokenId
        ] == true;

        //calculate claim amount
        uint256 claimAmount = calculateClaim(_distributionEventId, _tokenId);
        require(
            distributionEvents[_distributionEventId].distributedAmount +
                claimAmount <=
                distributionEvents[_distributionEventId].amount,
            "FantiumClaimingV1: distribution amount exceeded"
        );
        distributionEvents[_distributionEventId]
            .distributedAmount += claimAmount;

        // INTERACTIONS
        //upgrade token to new version
        require(
            fantiumNFTContract.upgradeTokenVersion(_tokenId),
            "FantiumClaimingV1: upgrade failed"
        );
        //transfer USDC to _msgSender()
        _splitFunds(claimAmount, _distributionEventId);
        
    }

    /*///////////////////////////////////////////////////////////////
                            INTERNAL 
    //////////////////////////////////////////////////////////////*/

    // calcualtes the amount to send to the user
    function calculateClaim(
        uint256 _distributionEventID,
        uint256 _tokenId
    ) internal view returns (uint256) {
        (uint256 collectionOfToken, , ) = TokenVersionUtil.getTokenInfo(
            _tokenId
        );

        uint256 share = fantiumNFTContract
            .getCollection(collectionOfToken)
            .tournamentEarningShare1e7;
        // calculate amount to send
        // note: divice by 1e7 will always down round amount at decimal.
        // note: add decimals for payout token (USDC = 6 decimals)
        uint256 claimAmount = (distributionEvents[_distributionEventID].amount *
            share *
            (10 ** ERC20(payoutToken).decimals())) / 1e7;
        return (claimAmount);
    }

    // check if token is from a valid collection and hasn't claimed yet for that distribution event
    function checkTokenAllowed(
        uint256 _distributionEventID,
        uint256 _collectionOfToken,
        uint256 _baseTokenId
    ) internal view returns (bool) {
        bool collectionIncluded = false;
        bool tokenNrIncluded = false;

        //check if payouts were claimed for this token
        if (
            distributionEventToTokenIdToClaimed[_distributionEventID][
                _baseTokenId
            ] == true
        ) {
            tokenNrIncluded = true;
        }

        //check if collection is included in distribution event
        for (
            uint256 i = 0;
            i < distributionEvents[_distributionEventID].collectionIds.length;
            i++
        ) {
            if (
                distributionEvents[_distributionEventID].collectionIds[i] ==
                _collectionOfToken
            ) {
                collectionIncluded = true;
            }
        }

        if (collectionIncluded && tokenNrIncluded) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev splits funds between receiver and
     * FANtium for a claim on a specific distribution event `_distributionEventId`
     */
    function _splitFunds(
        uint256 _claimAmount,
        uint256 _distributionEventId
    ) internal view {
        // split funds between user and Fantium

        // get fantium address & revenue from disitrbution Event
        DistributionEvent memory distributionEvent = distributionEvents[
            _distributionEventId
        ];

        // calculate fantium revenue
        uint256 fantiumRevenue_ = ((_claimAmount *
            uint256(distributionEvent.fantiumFeePBS)) / 10000) +
            (distributionEvent.fantiumTransactionFeeInWei);

        // calculate user revenue
        uint256 userRevenue_ = _claimAmount - fantiumRevenue_;

        // set addresses from storage
        address fantiumAddress_ = distributionEvents[_distributionEventId]
            .fantiumFeeAddress;

        // FANtium payment
        if (fantiumRevenue_ > 0) {
            IERC20(payoutToken).transferFrom(
                address(this),
                fantiumAddress_,
                fantiumRevenue_
            );
        }
        // yser payment
        if (userRevenue_ > 0) {
            IERC20(payoutToken).transferFrom(
                address(this),
                _msgSender(),
                userRevenue_
            );
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN
    //////////////////////////////////////////////////////////////*/

    // update fantiumNFTContract address
    function updateFantiumNFTContract(
        address _fantiumNFTContract
    ) external onlyManager whenNotPaused {
        fantiumNFTContract = FantiumNFTV4(_fantiumNFTContract);
    }

    // update payoutToken address
    function updatePayoutToken(
        address _payoutToken
    ) external onlyManager whenNotPaused {
        payoutToken = ERC20(_payoutToken);
    }

    function closeDistribution(
        uint256 _distributionEventId
    ) external onlyManager whenNotPaused {
        require(
            distributionEvents[_distributionEventId].closed = false,
            "FantiumClaimingV1: distribution already closed"
        );
        require(
            distributionEvents[_distributionEventId].exist = true,
            "FantiumClaimingV1: distributionEvent doesn't exist"
        );

        distributionEvents[_distributionEventId].closed = true;
        uint256 closingAmount = distributionEvents[_distributionEventId]
            .amount -
            distributionEvents[_distributionEventId].distributedAmount;
        IERC20(payoutToken).transferFrom(
            address(this),
            distributionEvents[_distributionEventId].athleteAddress,
            closingAmount
        );
    }

    /**
     * @notice Update contract pause status to `_paused`.
     */

    function pause() external onlyRole(PLATFORM_MANAGER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */

    function unpause() external onlyRole(PLATFORM_MANAGER_ROLE) {
        _unpause();
    }

    /*///////////////////////////////////////////////////////////////
                            OVERRIDE
    //////////////////////////////////////////////////////////////*/

    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (address sender)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextUpgradeable, ContextUpgradeable)
        returns (bytes calldata)
    {
        return super._msgData();
    }
}
