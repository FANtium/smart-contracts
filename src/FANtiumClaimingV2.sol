// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../interfaces/IFANtiumNFT.sol";
import "../interfaces/IFANtiumUserManager.sol";
import "../utils/TokenVersionUtil.sol";

/**
 * @title Claiming contract that allows payout tokens to be claimed
 * for FAN token holders.
 * @author MTX studoi AG.
 */

contract FANtiumClaimingV2 is Initializable, UUPSUpgradeable, AccessControlUpgradeable, PausableUpgradeable {
    address public globalPayoutToken;
    address private trustedForwarder;
    address public fantiumNFTContract;
    address public fantiumUserManager;

    // mapping of distributionEvent to TokenID to claimed
    mapping(uint256 => DistributionEvent) public distributionEvents;
    mapping(uint256 => mapping(uint256 => bool)) public distributionEventToBaseTokenToClaimed;
    mapping(uint256 => mapping(uint256 => collectionInfo)) public distributionEventToCollectionInfo;
    mapping(uint256 => address) public distributionEventToPayoutToken;

    uint256 private nextDistributionEventId;
    uint256 constant ONE_MILLION = 1_000_000;
    /// ACM
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE = keccak256("PLATFORM_MANAGER_ROLE");

    bytes32 constant FIELD_CREATED = "created";
    bytes32 constant FIELD_COLLECTIONS = "collection IDs";
    bytes32 constant FIELD_AMOUNT = "earning amounts";
    bytes32 constant FIELD_DISTRIBUTION_PERCENTAGE = "Distribution Percentage";
    bytes32 constant FIELD_ADDRESSES = "addresses";
    bytes32 constant FIELD_FANTIUMFEE = "fantium fee";
    bytes32 constant FIELD_CLOSED = "closed";
    bytes32 constant FIELD_TIMESTAMPS = "start and close timestamp";
    bytes32 constant FIELD_PAYOUT_CONTRACT_CONFIGS = "payout address config";
    bytes32 constant FIELD_NFT_CONTRACT_CONFIGS = "NFT address config";
    bytes32 constant FIELD_USER_MANAGER_CONFIGS = "userManager address config";
    bytes32 constant FIELD_FORWARDER_CONFIGS = "forwarder address config";

    struct DistributionEvent {
        uint256 distributionEventId;
        uint256[] collectionIds; // NFT collections allowed to claim
        address payable athleteAddress; // athlete address that need to pay in amount
        uint256 totalTournamentEarnings; // total earnings from tournaments with decimals
        uint256 totalOtherEarnings; // total earnings from other sources with decimals
        uint256 tournamentDistributionAmount; // total earnings to be distributed from tournaments with decimals
        uint256 otherDistributionAmount; // total earnings to be distributed from other sources with decimals
        uint256 amountPaidIn; // amount has been paid in
        uint256 claimedAmount; // total amount claimed so far
        uint256 fantiumFeeBPS; // fantium fee in basis points
        address payable fantiumFeeAddress;
        uint256 startTime; // start time of distribution event (can be 0 if it starts immediately)
        uint256 closeTime; // close time of distribution event (can be 0 if it never closes)
        bool exists;
        bool closed;
    }

    struct collectionInfo {
        uint256 mintedTokens;
        uint256 tokenTournamentClaim;
        uint256 tokenOtherClaim;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Claim(uint256 indexed _distributionEventId, uint256 indexed _tokenId, uint256 amount);
    event DistributionEventUpdate(uint256 indexed _distributionEventId, bytes32 indexed _field);
    event PayIn(uint256 indexed _distributionEventId, uint256 amount);
    event SnapShotTaken(uint256 indexed _distributionEventId);
    event PlatformUpdate(bytes32 indexed _update);

    /*//////////////////////////////////////////////////////////////
                            MODIFERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAthlete(uint256 _distributionEventId) {
        require(
            address(_msgSender()) == address(distributionEvents[_distributionEventId].athleteAddress) ||
                hasRole(PLATFORM_MANAGER_ROLE, msg.sender),
            "only athlete"
        );
        _;
    }

    modifier onlyValidDistributionEvent(uint256 _distributionEventId) {
        require(distributionEvents[_distributionEventId].exists, "Invalid distribution event");
        _;
    }

    modifier onlyPlatformManager() {
        require(hasRole(PLATFORM_MANAGER_ROLE, msg.sender), "only platform manager");
        _;
    }

    modifier onlyUpgrader() {
        require(hasRole(UPGRADER_ROLE, msg.sender), "only upgrader");
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
        address _defaultAdmin,
        address _payoutToken,
        address _fantiumNFTContract,
        address _trustedForwarder
    ) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();
        require(
            _defaultAdmin != address(0) &&
                _payoutToken != address(0) &&
                _fantiumNFTContract != address(0) &&
                _trustedForwarder != address(0),
            "Invalid addresses"
        );
        globalPayoutToken = _payoutToken;
        fantiumNFTContract = _fantiumNFTContract;
        trustedForwarder = _trustedForwarder;

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(UPGRADER_ROLE, _defaultAdmin);

        nextDistributionEventId = 1;
    }

    /// @notice upgrade authorization logic
    /// @dev required by the OZ UUPS module
    /// @dev adds onlyUpgrader requirement
    function _authorizeUpgrade(address) internal override onlyUpgrader {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
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
        require(fantiumUserManager != address(0), "FANtiumClaimingV1: FANtiumUserManager not set");
        return IFANtiumUserManager(fantiumUserManager).isAddressIDENT(_address);
    }

    function getDistributionEvent(uint256 _id) public view returns (DistributionEvent memory) {
        return distributionEvents[_id];
    }

    /*///////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    //
    function setupDistributionEvent(
        address payable _athleteAddress,
        uint256 _totalTournamentEarnings,
        uint256 _totalOtherEarnings,
        uint256 _startTime,
        uint256 _closeTime,
        uint256[] memory _collectionIds,
        address payable _fantiumAddress,
        uint256 _fantiumFeeBPS
    ) external onlyPlatformManager whenNotPaused {
        require(
            _startTime > 0 && _closeTime > 0 && _startTime < _closeTime && block.timestamp < _closeTime,
            "FANtiumClaimingV1: times must be greater than 0 and close time must be greater than start time and in the future"
        );
        require(_collectionIds.length > 0, "FANtiumClaimingV1: collectionIds must be greater than 0");
        require(_fantiumFeeBPS < 10_000, "FANtiumClaimingV1: fantium fee must be less than 10000");

        require(
            _athleteAddress != address(0) && _fantiumAddress != address(0),
            "FANtiumClaimingV1: addresses cannot be 0"
        );

        // check if amount is less than a billion
        require(
            (_totalTournamentEarnings + _totalOtherEarnings) > 0 &&
                (_totalTournamentEarnings + _totalOtherEarnings) <
                (1_000_000_000 * 10 ** ERC20Upgradeable(globalPayoutToken).decimals()),
            "FANtiumClaimingV1: amount must be less than a billion and greater than 0"
        );

        //check if collection exists
        for (uint256 i = 0; i < _collectionIds.length; i++) {
            bool collectionExists = IFANtiumNFT(fantiumNFTContract).getCollectionExists(_collectionIds[i]);
            require(collectionExists, "FANtiumClaimingV1: collection does not exist");
        }
        // EFFECTS
        DistributionEvent memory distributionEvent;
        distributionEvent.distributionEventId = nextDistributionEventId;
        distributionEvent.collectionIds = _collectionIds;
        distributionEvent.athleteAddress = _athleteAddress;
        distributionEvent.totalTournamentEarnings = _totalTournamentEarnings;
        distributionEvent.totalOtherEarnings = _totalOtherEarnings;
        distributionEvent.fantiumFeeAddress = _fantiumAddress;
        distributionEvent.fantiumFeeBPS = _fantiumFeeBPS;
        distributionEvent.startTime = _startTime;
        distributionEvent.closeTime = _closeTime;
        distributionEvent.exists = true;
        distributionEvent.closed = false;
        distributionEventToPayoutToken[nextDistributionEventId] = globalPayoutToken;
        distributionEvents[nextDistributionEventId] = distributionEvent;
        triggerClaimingSnapshot(nextDistributionEventId);
        emit DistributionEventUpdate(nextDistributionEventId, FIELD_CREATED);
        nextDistributionEventId++;
    }

    function batchAddDistributionAmount(uint256[] memory _distributionEventIds) external whenNotPaused {
        for (uint256 i = 0; i < _distributionEventIds.length; i++) {
            addDistributionAmount(_distributionEventIds[i]);
        }
    }

    function addDistributionAmount(
        uint256 _distributionEventId
    ) public whenNotPaused onlyAthlete(_distributionEventId) {
        // CHECKS
        require(
            distributionEvents[_distributionEventId].exists,
            "FANtiumClaimingV1: distributionEventId does not exist"
        );

        // check that the distribution event is open
        require(
            distributionEvents[_distributionEventId].closed == false,
            "FANtiumClaimingV1: distribution event not open"
        );

        uint256 payInAmount = (distributionEvents[_distributionEventId].tournamentDistributionAmount +
            distributionEvents[_distributionEventId].otherDistributionAmount) -
            distributionEvents[_distributionEventId].amountPaidIn;

        // check if a topup is needed
        require(payInAmount > 0, "FANtiumClaimingV1: amount already paid in");

        // EFFECT
        address payOutToken = distributionEventToPayoutToken[_distributionEventId];

        uint256 balanceBefore = IERC20Upgradeable(payOutToken).balanceOf(address(this));

        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(payOutToken), _msgSender(), address(this), payInAmount);

        require(
            balanceBefore + payInAmount == IERC20Upgradeable(payOutToken).balanceOf(address(this)),
            "FANtiumClaimingV1: transfer failed"
        );

        distributionEvents[_distributionEventId].amountPaidIn += payInAmount;
        emit PayIn(_distributionEventId, payInAmount);
    }

    /*///////////////////////////////////////////////////////////////
                            UPDATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateDistribtionTotalEarningsAmounts(
        uint256 _id,
        uint256 _totalTournamentEarnings,
        uint256 _totalOtherEarnings
    ) external onlyValidDistributionEvent(_id) onlyPlatformManager {
        require(!distributionEvents[_id].closed, "FANtiumClaimingV1: distribution already closed");
        require(
            distributionEvents[_id].claimedAmount == 0 && distributionEvents[_id].startTime > block.timestamp,
            "FANtiumClaimingV1: payout already started"
        );

        require(
            (_totalTournamentEarnings + _totalOtherEarnings) > 0,
            "FANtiumClaimingV1: total amount must be greater than 0"
        );

        distributionEvents[_id].totalTournamentEarnings = _totalTournamentEarnings;
        distributionEvents[_id].totalOtherEarnings = _totalOtherEarnings;

        triggerClaimingSnapshot(_id);
        require(
            (distributionEvents[_id].tournamentDistributionAmount + distributionEvents[_id].otherDistributionAmount) >=
                distributionEvents[_id].amountPaidIn,
            "FANtiumClaimingV1: total payout amount must be greater than amount already paid in"
        );
        emit DistributionEventUpdate(_id, FIELD_AMOUNT);
    }

    function updateDistributionEventCollectionIds(
        uint256 _id,
        uint256[] memory collectionIds
    ) external onlyValidDistributionEvent(_id) onlyPlatformManager {
        require(!distributionEvents[_id].closed, "FANtiumClaimingV1: distribution already closed");
        require(
            distributionEvents[_id].claimedAmount == 0 && distributionEvents[_id].startTime > block.timestamp,
            "FANtiumClaimingV1: payout already started"
        );

        require(collectionIds.length > 0, "FANtiumClaimingV1: collectionIds length must be greater than 0");

        for (uint256 i = 0; i < collectionIds.length; i++) {
            bool collectionExists = IFANtiumNFT(fantiumNFTContract).getCollectionExists(collectionIds[i]);
            require(collectionExists, "FANtiumClaimingV1: collection does not exist");
        }

        distributionEvents[_id].collectionIds = collectionIds;
        triggerClaimingSnapshot(_id);
        require(
            (distributionEvents[_id].tournamentDistributionAmount + distributionEvents[_id].otherDistributionAmount) >=
                distributionEvents[_id].amountPaidIn,
            "FANtiumClaimingV1: total payout amount must be greater than amount already paid in"
        );

        emit DistributionEventUpdate(_id, FIELD_COLLECTIONS);
    }

    function updateDistributionEventAddresses(
        uint256 _id,
        address payable _athleteAddress,
        address payable _fantiumAdress
    ) external onlyValidDistributionEvent(_id) onlyPlatformManager {
        require(
            _athleteAddress != address(0) && _fantiumAdress != address(0),
            "FANtiumClaimingV1: athlete address cannot be 0"
        );
        distributionEvents[_id].athleteAddress = _athleteAddress;
        distributionEvents[_id].fantiumFeeAddress = _fantiumAdress;
        emit DistributionEventUpdate(_id, FIELD_ADDRESSES);
    }

    function updateDistributionEventTimeStamps(
        uint256 _id,
        uint256 _startTime,
        uint256 _closeTime
    ) external onlyValidDistributionEvent(_id) onlyPlatformManager {
        require(
            _startTime > 0 && _closeTime > 0 && _startTime < _closeTime && block.timestamp < _closeTime,
            "FANtiumClaimingV1: times must be greater than 0 and close time must be greater than start time and in the future"
        );
        distributionEvents[_id].startTime = _startTime;
        distributionEvents[_id].closeTime = _closeTime;
        emit DistributionEventUpdate(_id, FIELD_TIMESTAMPS);
    }

    function updateDistributionEventFee(
        uint256 _id,
        uint256 _feeBPS
    ) external onlyValidDistributionEvent(_id) onlyPlatformManager {
        require(distributionEvents[_id].claimedAmount == 0, "FANtiumClaimingV1: payout already started");

        require(_feeBPS >= 0 && _feeBPS < 10000, "FANtiumClaimingV1: fee must be between 0 and 10000");
        distributionEvents[_id].fantiumFeeBPS = _feeBPS;
        emit DistributionEventUpdate(_id, FIELD_FANTIUMFEE);
    }

    /*///////////////////////////////////////////////////////////////
                            CLAIMING
    //////////////////////////////////////////////////////////////*/

    function batchClaim(uint256[] memory _tokenIds, uint256[] memory _distributionEventID) external whenNotPaused {
        require(_tokenIds.length == _distributionEventID.length, "FANtiumClaimingV1: Arrays must be of same length");
        require(_tokenIds.length <= 100, "FANtiumClaimingV1: Arrays must be of length <= 100");

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            claim(_tokenIds[i], _distributionEventID[i]);
        }
    }

    function claim(
        uint256 _tokenId,
        uint256 _distributionEventId
    ) public whenNotPaused onlyValidDistributionEvent(_distributionEventId) {
        // CHECKS

        // check if distribution Event was paid in in full
        require(
            distributionEvents[_distributionEventId].amountPaidIn ==
                (distributionEvents[_distributionEventId].tournamentDistributionAmount +
                    distributionEvents[_distributionEventId].otherDistributionAmount),
            "FANtiumClaimingV1: total distribution amount has not been paid in"
        );

        //check if _msgSender() has FAN token Id
        require(
            _msgSender() == IERC721Upgradeable(fantiumNFTContract).ownerOf(_tokenId),
            "FANtiumClaimingV1: Only token owner"
        );

        //check if _msgSender() is IDENTed
        require(isAddressIDENT(_msgSender()), "FANtiumClaimingV1: Only ID verified");

        //check if lockTime is over or ca be ignored
        require(
            distributionEvents[_distributionEventId].startTime < block.timestamp &&
                distributionEvents[_distributionEventId].closeTime > block.timestamp,
            "FANtiumClaimingV1: distribution time has not started or has ended"
        );

        // check if distribution event is closed
        require(
            distributionEvents[_distributionEventId].closed == false,
            "FANtiumClaimingV1: distribution event is closed"
        );

        // check if token is from a valid collection
        // check that hasn't claimed yet for that distribution event
        (uint256 collectionOfToken, , uint256 tokenNr) = TokenVersionUtil.getTokenInfo(_tokenId);
        uint256 baseTokenId = collectionOfToken * 1000000 + tokenNr;
        // check if token alreadu claimed
        require(
            checkTokenAllowed(_distributionEventId, collectionOfToken, baseTokenId, tokenNr),
            "FANtiumClaimingV1: token not allowed"
        );

        // EFFECTS
        //set claimed to true
        distributionEventToBaseTokenToClaimed[_distributionEventId][baseTokenId] = true;

        //calculate claim amount
        uint256 tournamentClaim = distributionEventToCollectionInfo[_distributionEventId][collectionOfToken]
            .tokenTournamentClaim;
        uint256 otherClaim = distributionEventToCollectionInfo[_distributionEventId][collectionOfToken].tokenOtherClaim;
        uint256 claimAmount = tournamentClaim + otherClaim;

        require(
            distributionEvents[_distributionEventId].claimedAmount + claimAmount <=
                distributionEvents[_distributionEventId].amountPaidIn,
            "FANtiumClaimingV1: distribution amount exceeds payInAmount"
        );
        distributionEvents[_distributionEventId].claimedAmount += claimAmount;

        // INTERACTIONS
        //upgrade token to new version
        require(IFANtiumNFT(fantiumNFTContract).upgradeTokenVersion(_tokenId), "FANtiumClaimingV1: upgrade failed");
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
        uint256 _tournamentEarningsShare1e7,
        uint256 _otherEarningShare1e7
    ) internal view returns (uint256, uint256) {
        require(
            (_tournamentEarningsShare1e7 > 0) || (_otherEarningShare1e7 > 0),
            "FANtiumClaimingV1: Token has no earnings"
        );
        // calculate amount to send
        // note: totalTorunamentEarnings = Total amount of earnings from tournaments
        // note: tournamentShare1e7 = % share of fan of total athlete earnings in 1e7 e.g. 0,00001% == 0,0000001 == 1
        // note: dividing by 1e7 to get the share in base 10
        // note: Get the total distribution amount and multiple it by the token share and devide it by the overall share distributed
        // note: Example calculation for one token with 1% share: 100_000 USDC (amount) * 10.000.000(1e7)(share) / 1e7  = 1000 USDC
        uint256 tournamentClaim = ((distributionEvents[_distributionEventID].totalTournamentEarnings *
            _tournamentEarningsShare1e7) / 1e7);

        uint256 otherClaim = ((distributionEvents[_distributionEventID].totalOtherEarnings * _otherEarningShare1e7) /
            1e7);

        return (tournamentClaim, otherClaim);
    }

    // check if token is from a valid collection and hasn't claimed yet for that distribution event
    function checkTokenAllowed(
        uint256 _distributionEventID,
        uint256 _collectionOfToken,
        uint256 _baseTokenId,
        uint256 _tokenNr
    ) internal view returns (bool) {
        bool collectionIncluded = false;
        bool tokenNrClaimed = false;
        bool tokenInSnapshot = true;

        //check if payouts were claimed for this token
        tokenNrClaimed = distributionEventToBaseTokenToClaimed[_distributionEventID][_baseTokenId];

        if (!tokenNrClaimed) {
            //check if collection is included in distribution event
            for (uint256 i = 0; i < distributionEvents[_distributionEventID].collectionIds.length; i++) {
                // checking if the token is from a collection that is included in the distribution event
                uint256 collectionID = distributionEvents[_distributionEventID].collectionIds[i];
                if (collectionID == _collectionOfToken) {
                    collectionIncluded = true;
                    // check if tokenNr is in snapshot
                    if (
                        _tokenNr >= distributionEventToCollectionInfo[_distributionEventID][collectionID].mintedTokens
                    ) {
                        tokenInSnapshot = false;
                    }
                    break;
                }
            }
        }
        return (collectionIncluded && !tokenNrClaimed && tokenInSnapshot);
    }

    /**
     * @dev splits funds between receiver and
     * FANtium for a claim on a specific distribution event `_distributionEventId`
     */
    function _splitFunds(uint256 _claimAmount, uint256 _distributionEventId) internal {
        // split funds between user and FANtium

        // get fantium address & revenue from disitrbution Event
        DistributionEvent memory distributionEvent = distributionEvents[_distributionEventId];

        // calculate fantium revenue
        uint256 fantiumRevenue_ = ((_claimAmount * distributionEvent.fantiumFeeBPS) / 10000);

        // calculate user revenue
        uint256 userRevenue_ = _claimAmount - fantiumRevenue_;

        // set addresses from storage
        address fantiumAddress_ = distributionEvents[_distributionEventId].fantiumFeeAddress;

        address payOutToken = distributionEventToPayoutToken[_distributionEventId];

        // FANtium payment
        if (fantiumRevenue_ > 0) {
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(payOutToken), fantiumAddress_, fantiumRevenue_);
        }
        // yser payment
        if (userRevenue_ > 0) {
            SafeERC20Upgradeable.safeTransfer(IERC20Upgradeable(payOutToken), _msgSender(), userRevenue_);
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN
    //////////////////////////////////////////////////////////////*/

    // take tokenSnapshot by platform manager
    function takeClaimingSnapshot(
        uint256 _distributionEventId
    ) external onlyPlatformManager onlyValidDistributionEvent(_distributionEventId) {
        triggerClaimingSnapshot(_distributionEventId);
        emit SnapShotTaken(_distributionEventId);
    }

    // automatic trigger for taking tokenSnapshot for claiming
    function triggerClaimingSnapshot(uint256 _distributionEventId) internal {
        uint256 holdersTournamentEarningsShare1e7;
        uint256 holdersOtherEarningsShare1e7;

        for (uint256 i = 0; i < distributionEvents[_distributionEventId].collectionIds.length; i++) {
            uint256 collectionId = distributionEvents[_distributionEventId].collectionIds[i];
            uint256 mintedTokens = IFANtiumNFT(fantiumNFTContract).getMintedTokensOfCollection(collectionId);
            (uint256 tournamentEarningShare1e7, uint256 otherEarningShare1e7) = IFANtiumNFT(fantiumNFTContract)
                .getEarningsShares1e7(collectionId);

            (uint256 tournamentClaim, uint256 otherClaim) = calculateClaim(
                _distributionEventId,
                tournamentEarningShare1e7,
                otherEarningShare1e7
            );

            distributionEventToCollectionInfo[_distributionEventId][collectionId].mintedTokens = mintedTokens;
            distributionEventToCollectionInfo[_distributionEventId][collectionId]
                .tokenTournamentClaim = tournamentClaim;
            distributionEventToCollectionInfo[_distributionEventId][collectionId].tokenOtherClaim = otherClaim;

            holdersTournamentEarningsShare1e7 += (mintedTokens * tournamentEarningShare1e7);
            holdersOtherEarningsShare1e7 += (mintedTokens * otherEarningShare1e7);
        }

        distributionEvents[_distributionEventId].tournamentDistributionAmount =
            (holdersTournamentEarningsShare1e7 * distributionEvents[_distributionEventId].totalTournamentEarnings) /
            1e7;
        distributionEvents[_distributionEventId].otherDistributionAmount =
            (holdersOtherEarningsShare1e7 * distributionEvents[_distributionEventId].totalOtherEarnings) /
            1e7;
    }

    // update fantiumNFTContract address
    function updateFANtiumNFTContract(address _fantiumNFTContract) external onlyPlatformManager {
        require(_fantiumNFTContract != address(0), "Null address not allowed");
        fantiumNFTContract = _fantiumNFTContract;
        emit PlatformUpdate(FIELD_NFT_CONTRACT_CONFIGS);
    }

    // update payoutToken address
    function updateGlobalPayoutToken(address _globalPayoutToken) external onlyPlatformManager {
        require(_globalPayoutToken != address(0), "Null address not allowed");
        globalPayoutToken = _globalPayoutToken;
        emit PlatformUpdate(FIELD_PAYOUT_CONTRACT_CONFIGS);
    }

    // update payoutToken address
    function updateFANtiumUserManager(address _fantiumUserManager) external onlyPlatformManager {
        require(_fantiumUserManager != address(0), "Null address not allowed");
        fantiumUserManager = _fantiumUserManager;
        emit PlatformUpdate(FIELD_USER_MANAGER_CONFIGS);
    }

    function closeDistribution(
        uint256 _distributionEventId
    ) external onlyPlatformManager whenNotPaused onlyValidDistributionEvent(_distributionEventId) {
        require(
            distributionEvents[_distributionEventId].closed == false,
            "FANtiumClaimingV1: distribution already closed"
        );

        // check if the athlete address is set
        require(
            distributionEvents[_distributionEventId].athleteAddress != address(0),
            "FANtiumClaimingV1: Athlete address not set yet"
        );

        distributionEvents[_distributionEventId].closed = true;
        uint256 closingAmount = distributionEvents[_distributionEventId].amountPaidIn -
            distributionEvents[_distributionEventId].claimedAmount;

        require(closingAmount > 0, "FANtiumClaimingV1: Amount to pay is 0");

        address payOutToken = distributionEventToPayoutToken[_distributionEventId];

        SafeERC20Upgradeable.safeTransfer(
            IERC20Upgradeable(payOutToken),
            distributionEvents[_distributionEventId].athleteAddress,
            closingAmount
        );

        emit DistributionEventUpdate(_distributionEventId, FIELD_CLOSED);
    }

    /**
     * @notice Update contract pause status to `_paused`.
     */

    function pause() external onlyPlatformManager {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */

    function unpause() external onlyPlatformManager {
        _unpause();
    }

    /*///////////////////////////////////////////////////////////////
                            ERC2771
    //////////////////////////////////////////////////////////////*/

    function setTrustedForwarder(address forwarder) external onlyUpgrader {
        trustedForwarder = forwarder;
        emit PlatformUpdate(FIELD_FORWARDER_CONFIGS);
    }

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == trustedForwarder;
    }

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

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
}
