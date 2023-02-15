// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IFantiumNFT.sol";
import "../interfaces/IFantiumUserManager.sol";
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
    address public payoutToken;
    address public fantiumNFTContract;
    address public fantiumUserManager;

    // mapping of distributionEvent to TokenID to claimed
    mapping(uint256 => DistributionEvent) public distributionEvents;
    mapping(uint256 => mapping(uint256 => bool))
        public distributionEventToTokenIdToClaimed;

    uint256 private nextDistributionEventId;
    uint256 constant ONE_MILLION = 1_000_000;
    /// ACM
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE =
        keccak256("PLATFORM_MANAGER_ROLE");

    bytes32 constant FIELD_CREATED = "created";
    bytes32 constant FIELD_COLLECTIONS = "collections";
    bytes32 constant FIELD_AMOUNT = "amount";
    bytes32 constant FIELD_DISTRIBUTION_PERCENTAGE = "Distribution Percentage";
    bytes32 constant FIELD_ADDRESSES = "addresses";
    bytes32 constant FIELD_FANTIUMFEEBPS = "fantium fee basis points";
    bytes32 constant FIELD_CLOSED = "isClosed";
    bytes32 constant FIELD_TIMESTAMPS = "start and close timestamp";

    struct DistributionEvent {
        uint256 distributionEventId;
        uint256[] collectionIds;
        address payable athleteAddress;
        uint256 tournamentDistributionAmount;
        uint256 otherDistributionAmount;
        uint256 claimedAmount;
        uint256 fantiumFeeBPS;
        address payable fantiumFeeAddress;
        uint256 startTime;
        uint256 closeTime;
        bool exists;
        bool amountPaidIn;
        bool closed;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Claim(
        uint256 indexed _distributionEventId,
        uint256 indexed _tokenId,
        uint256 amount
    );
    event DistributionEventUpdate(
        uint256 indexed _distributionEventId,
        bytes32 indexed _field
    );
    event AddDistributionEventAmount(uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            MODIFERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAthlete(uint256 _distributionEventId) {
        require(
            _msgSender() ==
                distributionEvents[_distributionEventId].athleteAddress ||
                hasRole(PLATFORM_MANAGER_ROLE, _msgSender()),
            "only athlete"
        );
        _;
    }

    modifier onlyManager() {
        require(hasRole(PLATFORM_MANAGER_ROLE, _msgSender()), "only Manager");
        _;
    }

    modifier onlyTokenOwner(uint256 _tokenId) {
        require(
            IERC721Upgradeable(fantiumNFTContract).ownerOf(_tokenId) ==
                _msgSender(),
            "Only token owner"
        );
        _;
    }

    modifier onlyValidAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }

    modifier onlyValidDistributionEvent(uint256 _distributionEventId) {
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
        payoutToken = _payoutToken;
        fantiumNFTContract = _fantiumNFTContract;

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
        require(
            fantiumUserManager != address(0),
            "FantiumClaimingV1: FantiumUserManager not set"
        );
        return IFantiumUserManager(fantiumUserManager).isAddressIDENT(_address);
    }

    function getDistributionEvent(
        uint256 _id
    ) public view returns (DistributionEvent memory) {
        return distributionEvents[_id];
    }

    /*///////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    //
    function setupDistributionEvent(
        address payable _athleteAddress,
        uint256 _tournamentDistributionAmount,
        uint256 _otherDistributionAmount,
        uint256 _startTime,
        uint256 _closeTime,
        uint256[] memory _collectionIds,
        address payable _fantiumAddress,
        uint256 _fantiumFeeBPS
    ) external onlyManager whenNotPaused onlyValidAddress(_athleteAddress) {
        // CHECKS
        require(
            fantiumNFTContract != address(0),
            "FantiumClaimingV1: FantiumNFT not set"
        );

        require(
            _startTime > 0 && _closeTime > 0 && _startTime < _closeTime,
            "FantiuyarnmClaimingV1: times must be greater than 0 and close time must be greater than start time"
        );
        require(
            _collectionIds.length > 0,
            "FantiumClaimingV1: collectionIds must be greater than 0"
        );
        // check if amount is less than a billion
        require(
            (_tournamentDistributionAmount + _otherDistributionAmount) > 0 &&
                (_tournamentDistributionAmount + _otherDistributionAmount) <
                10000000000000000,
            "FantiumClaimingV1: amount must be less than a ten billion and greater than 0"
        );

        //check if collection exists
        for (uint256 i = 0; i < _collectionIds.length; i++) {
            bool collectionExists = IFantiumNFT(fantiumNFTContract)
                .getCollectionExists(_collectionIds[i]);
            require(
                collectionExists,
                "FantiumClaimingV1: collection does not exist"
            );
        }
        // EFFECTS
        DistributionEvent memory distributionEvent;
        distributionEvent.distributionEventId = nextDistributionEventId;
        distributionEvent
            .tournamentDistributionAmount = _tournamentDistributionAmount;
        distributionEvent.otherDistributionAmount = _otherDistributionAmount;
        distributionEvent.collectionIds = _collectionIds;
        distributionEvent.athleteAddress = _athleteAddress;
        distributionEvent.fantiumFeeAddress = _fantiumAddress;
        distributionEvent.fantiumFeeBPS = _fantiumFeeBPS;
        distributionEvent.startTime = _startTime;
        distributionEvent.closeTime = _closeTime;
        distributionEvent.exists = true;
        distributionEvent.amountPaidIn = false;
        distributionEvent.closed = false;
        distributionEvents[nextDistributionEventId] = distributionEvent;
        emit DistributionEventUpdate(nextDistributionEventId, FIELD_CREATED);
        nextDistributionEventId++;
    }

    function addDistributionAmount(
        uint256 _distributionEventId,
        uint256 _amountWithDecimals
    ) external whenNotPaused onlyAthlete(_distributionEventId) {
        // CHECKS
        require(
            distributionEvents[_distributionEventId].exists,
            "FantiumClaimingV1: distributionEventId does not exist"
        );
        require(
            _amountWithDecimals ==
                (distributionEvents[_distributionEventId]
                    .tournamentDistributionAmount +
                    distributionEvents[_distributionEventId]
                        .otherDistributionAmount),
            "FantiumClaimingV1: amount must be equal to distribution amount"
        );

        require(
            !distributionEvents[_distributionEventId].amountPaidIn,
            "FantiumClaimingV1: amount already paid in"
        );

        // EFFECTS
        IERC20(payoutToken).transferFrom(
            _msgSender(),
            address(this),
            _amountWithDecimals
        );
        distributionEvents[_distributionEventId].amountPaidIn = true;
        emit AddDistributionEventAmount(_amountWithDecimals);
    }

    /*///////////////////////////////////////////////////////////////
                            UPDATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateDistributionEventAmount(
        uint256 _id,
        uint256 _tournamentAmount,
        uint256 _otherAmount
    )
        external
        whenNotPaused
        onlyValidDistributionEvent(_id)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        distributionEvents[_id]
            .tournamentDistributionAmount = _tournamentAmount;
        distributionEvents[_id].otherDistributionAmount = _otherAmount;
        emit DistributionEventUpdate(_id, FIELD_AMOUNT);
    }

    function updateDistributionEventAmount(
        uint256 _id,
        uint256[] memory collectionIds
    )
        external
        whenNotPaused
        onlyValidDistributionEvent(_id)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        distributionEvents[_id].collectionIds = collectionIds;
        emit DistributionEventUpdate(_id, FIELD_COLLECTIONS);
    }

    function updateDistributionEventAddresses(
        uint256 _id,
        address payable _athleteAddress,
        address payable _fantiumAdress
    )
        external
        whenNotPaused
        onlyValidDistributionEvent(_id)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        require(
            _athleteAddress != address(0) && _fantiumAdress != address(0),
            "FantiumClaimingV1: athlete address cannot be 0"
        );
        distributionEvents[_id].athleteAddress = _athleteAddress;
        distributionEvents[_id].fantiumFeeAddress = _fantiumAdress;
        emit DistributionEventUpdate(_id, FIELD_ADDRESSES);
    }

    function updateDistributionEventAddresses(
        uint256 _id,
        uint256 _startTime,
        uint256 _closeTime
    )
        external
        whenNotPaused
        onlyValidDistributionEvent(_id)
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

    function updateDistributionEventFee(
        uint256 _id,
        uint256 _feeBPS
    )
        external
        whenNotPaused
        onlyValidDistributionEvent(_id)
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
    )
        public
        onlyTokenOwner(_tokenId)
        whenNotPaused
        onlyValidDistributionEvent(_distributionEventId)
    {
        // CHECKS

        //check if _msgSender() has FAN token Id
        require(
            _msgSender() ==
                IERC721Upgradeable(fantiumNFTContract).ownerOf(_tokenId),
            "FantiumClaimingV1: You do not own this token"
        );

        //check if _msgSender() is IDENTed
        require(
            isAddressIDENT(_msgSender()),
            "FantiumClaimingV1: You are not ID verified"
        );

        //check if lockTime is over
        require(
            distributionEvents[_distributionEventId].startTime <
                block.timestamp &&
                distributionEvents[_distributionEventId].closeTime >
                block.timestamp,
            "FantiumClaimingV1: distribution time has not started or has ended"
        );

        require(
            distributionEvents[_distributionEventId].closed == false,
            "FantiumClaimingV1: distribution event is closed"
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
            distributionEvents[_distributionEventId].claimedAmount +
                claimAmount <=
                (distributionEvents[_distributionEventId]
                    .tournamentDistributionAmount +
                    distributionEvents[_distributionEventId]
                        .otherDistributionAmount),
            "FantiumClaimingV1: distribution amount exceeded"
        );
        distributionEvents[_distributionEventId].claimedAmount += claimAmount;

        // INTERACTIONS
        //upgrade token to new version
        require(
            IFantiumNFT(fantiumNFTContract).upgradeTokenVersion(_tokenId),
            "FantiumClaimingV1: upgrade failed"
        );
        //transfer USDC to _msgSender()
        _splitFunds(claimAmount, _distributionEventId);
        emit Claim(_distributionEventId, _tokenId, claimAmount);
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

        (uint256 tournamentShare1e7, uint256 tournamentTotalBPS) = IFantiumNFT(
            fantiumNFTContract
        ).getTournamentEarnings(collectionOfToken);

        (uint256 otherEarningsShare, uint256 otherTotalBPS) = IFantiumNFT(
            fantiumNFTContract
        ).getOtherEarnings(collectionOfToken);

        require(
            (tournamentShare1e7 > 0 && tournamentTotalBPS > 0) ||
                (otherEarningsShare > 0 && otherTotalBPS > 0),
            "FantiumClaimingV1: Token has no earnings"
        );
        // calculate amount to send
        // note: amountWithDecimals = Total amount distributed to fans. Only share of overal athlete earnings
        // note: athleteOverallDistributionBPS = Percentage of athlete earnings that are distributed to fans. e.g. 10% of total earnings
        // note: share = % share of fan of total athlete earnings in 1e7 e.g. 0,00001% == 0,0000001 == 1
        // note: Get the total distribution amount and multiple it by the token share and devide it by the overall share distributed
        // note: Example calculation for one token with 1% share: 100000 USDC (amount) * 10.000.000(1e7)(share) / 10%(shareOfOveral) / 1e7  = 10000 USDC
        uint256 tournamentClaim = ((distributionEvents[_distributionEventID]
            .tournamentDistributionAmount *
            tournamentShare1e7 *
            10000) /
            tournamentTotalBPS /
            1e7);

        uint256 otherClaim = ((distributionEvents[_distributionEventID]
            .otherDistributionAmount *
            otherEarningsShare *
            10000) /
            otherTotalBPS /
            1e7);

        return (tournamentClaim + otherClaim);
    }

    // check if token is from a valid collection and hasn't claimed yet for that distribution event
    function checkTokenAllowed(
        uint256 _distributionEventID,
        uint256 _collectionOfToken,
        uint256 _baseTokenId
    ) internal view returns (bool) {
        bool collectionIncluded = false;
        bool tokenNrClaimed = false;

        //check if payouts were claimed for this token
        tokenNrClaimed = distributionEventToTokenIdToClaimed[
            _distributionEventID
        ][_baseTokenId];

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
        return (collectionIncluded && !tokenNrClaimed);
    }

    /**
     * @dev splits funds between receiver and
     * FANtium for a claim on a specific distribution event `_distributionEventId`
     */
    function _splitFunds(
        uint256 _claimAmount,
        uint256 _distributionEventId
    ) internal {
        // split funds between user and Fantium

        // get fantium address & revenue from disitrbution Event
        DistributionEvent memory distributionEvent = distributionEvents[
            _distributionEventId
        ];

        // calculate fantium revenue
        uint256 fantiumRevenue_ = ((_claimAmount *
            uint256(distributionEvent.fantiumFeeBPS)) / 10000);

        // calculate user revenue
        uint256 userRevenue_ = _claimAmount - fantiumRevenue_;

        // set addresses from storage
        address fantiumAddress_ = distributionEvents[_distributionEventId]
            .fantiumFeeAddress;

        // FANtium payment
        if (fantiumRevenue_ > 0) {
            IERC20(payoutToken).transfer(fantiumAddress_, fantiumRevenue_);
        }
        // yser payment
        if (userRevenue_ > 0) {
            IERC20(payoutToken).transfer(_msgSender(), userRevenue_);
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN
    //////////////////////////////////////////////////////////////*/

    // update fantiumNFTContract address
    function updateFantiumNFTContract(
        address _fantiumNFTContract
    ) external onlyManager whenNotPaused {
        fantiumNFTContract = _fantiumNFTContract;
    }

    // update payoutToken address
    function updatePayoutToken(
        address _payoutToken
    ) external onlyManager whenNotPaused {
        payoutToken = _payoutToken;
    }

    // update payoutToken address
    function updateFantiumUserManager(
        address _fantiumUserManager
    ) external onlyManager whenNotPaused {
        fantiumUserManager = _fantiumUserManager;
    }

    function closeDistribution(
        uint256 _distributionEventId
    )
        external
        onlyManager
        whenNotPaused
        onlyValidDistributionEvent(_distributionEventId)
    {
        require(
            distributionEvents[_distributionEventId].closed = false,
            "FantiumClaimingV1: distribution already closed"
        );
        require(
            distributionEvents[_distributionEventId].exists = true,
            "FantiumClaimingV1: distributionEvent doesn't exist"
        );

        distributionEvents[_distributionEventId].closed = true;
        uint256 closingAmount = distributionEvents[_distributionEventId]
            .tournamentDistributionAmount +
            distributionEvents[_distributionEventId].otherDistributionAmount -
            distributionEvents[_distributionEventId].claimedAmount;

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
                            ERC2771
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
