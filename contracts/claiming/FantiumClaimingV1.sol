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
    AccessControlUpgradeable,
    PausableUpgradeable
{
    address public payoutToken;
    address private trustedForwarder; 
    address public fantiumNFTContract;
    address public fantiumUserManager;

    // mapping of distributionEvent to TokenID to claimed
    mapping(uint256 => DistributionEvent) public distributionEvents;
    mapping(uint256 => mapping(uint256 => bool))
        public distributionEventToBaseTokenToClaimed;

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
        uint256[] mintedTokens;
        address payable athleteAddress;
        uint256 totalTournamentEarnings; // total earnings from tournaments with decimals
        uint256 totalOtherEarnings; // total earnings from other sources with decimals
        uint256 tournamentDistributionAmount; // total earnings to be distributed from tournaments with decimals
        uint256 otherDistributionAmount;  // total earnings to be distributed from other sources with decimals
        uint256 amountPaidIn; // amount has been paid in
        uint256 claimedAmount; // total amount claimed so far
        uint256 fantiumFeeBPS; // fantium fee in basis points
        address payable fantiumFeeAddress; 
        uint256 startTime; // start time of distribution event (can be 0 if it starts immediately)
        uint256 closeTime; // close time of distribution event (can be 0 if it never closes)
        bool exists; 
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
        address _defaultAdmin,
        address _payoutToken,
        address _fantiumNFTContract,
        address _forwarder
    ) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();
        payoutToken = _payoutToken;
        fantiumNFTContract = _fantiumNFTContract;
        trustedForwarder = _forwarder;

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
        uint256 _totalTournamentEarnings,
        uint256 _totalOtherEarnings,
        uint256 _startTime,
        uint256 _closeTime,
        uint256[] memory _collectionIds,
        address payable _fantiumAddress,
        uint256 _fantiumFeeBPS
    ) external onlyRole(PLATFORM_MANAGER_ROLE) whenNotPaused onlyValidAddress(_athleteAddress) {
        // CHECKS
        require(
            fantiumNFTContract != address(0),
            "FantiumClaimingV1: FantiumNFT not set"
        );

        require(
            _startTime > 0 && _closeTime > 0 && _startTime < _closeTime && block.timestamp < _closeTime,
            "FantiumClaimingV1: times must be greater than 0 and close time must be greater than start time and in the future"
        );
        require(
            _collectionIds.length > 0,
            "FantiumClaimingV1: collectionIds must be greater than 0"
        );
        require(
            _fantiumFeeBPS < 10_000,
            "FantiumClaimingV1: fantium fee must be less than 10000"
        );

        require(
            _athleteAddress != address(0) && _fantiumAddress != address(0), 
            "FantiumClaimingV1: addresses cannot be 0"
        );

        // check if amount is less than a billion
        require(
            (_totalTournamentEarnings + _totalOtherEarnings) > 0 &&
                (_totalTournamentEarnings + _totalOtherEarnings) <
                (1_000_000_000 * 10 ** ERC20Upgradeable(payoutToken).decimals()),
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
        distributionEvents[nextDistributionEventId] = distributionEvent;
        triggerClaimingSnapshot(nextDistributionEventId);
        emit DistributionEventUpdate(nextDistributionEventId, FIELD_CREATED);
        nextDistributionEventId++;
        
        
    }

    function batchAddDistributionAmount(
        uint256[] memory _distributionEventIds
    ) external whenNotPaused {
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
            "FantiumClaimingV1: distributionEventId does not exist"
        );

        // check that the distribution event is open
        require(
            distributionEvents[_distributionEventId].closed == false,
            "FantiumClaimingV1: distribution event not open"
        );

        uint256 payInAmount = (distributionEvents[_distributionEventId].tournamentDistributionAmount + distributionEvents[_distributionEventId].otherDistributionAmount) - distributionEvents[_distributionEventId].amountPaidIn;

        // check if a topup is needed
        require(
            payInAmount > 0,
            "FantiumClaimingV1: amount already paid in"
        );

        // EFFECTS

        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(payoutToken),
            _msgSender(),
            address(this),
            payInAmount
        );

        distributionEvents[_distributionEventId].amountPaidIn += payInAmount;
        emit AddDistributionEventAmount(payInAmount);
    }

    /*///////////////////////////////////////////////////////////////
                            UPDATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateDistribtionTotalEarningsAmounts(
        uint256 _id,
        uint256 _totalTournamentEarnings,
        uint256 _totalOtherEarnings
    )
        external
        onlyValidDistributionEvent(_id)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        require((_totalTournamentEarnings + _totalOtherEarnings) > 0 , "FantiumClaimingV1: total amount must be greater than 0");
        require((_totalTournamentEarnings + _totalOtherEarnings) > distributionEvents[_id].amountPaidIn, "FantiumClaimingV1: total amount must be greater than amount already paid in");

        distributionEvents[_id].totalTournamentEarnings = _totalTournamentEarnings;
        distributionEvents[_id].totalOtherEarnings = _totalOtherEarnings;
        triggerClaimingSnapshot(_id);

        emit DistributionEventUpdate(_id, FIELD_AMOUNT);
    }

    function updateDistributionEventCollectionIds(
        uint256 _id,
        uint256[] memory collectionIds
    )
        external
        onlyValidDistributionEvent(_id)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        for (uint256 i = 0; i < collectionIds.length; i++) {
            bool collectionExists = IFantiumNFT(fantiumNFTContract)
                .getCollectionExists(collectionIds[i]);
            require(
                collectionExists,
                "FantiumClaimingV1: collection does not exist"
            );
        }
        require(
            distributionEvents[_id].amountPaidIn == 0,
            "Distribution Amount already paid in"
        );
        distributionEvents[_id].collectionIds = collectionIds;
        emit DistributionEventUpdate(_id, FIELD_COLLECTIONS);
    }

    function updateDistributionEventAddresses(
        uint256 _id,
        address payable _athleteAddress,
        address payable _fantiumAdress
    )
        external
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
        onlyValidDistributionEvent(_id)
        onlyRole(PLATFORM_MANAGER_ROLE)
    {
        require(
            _startTime > 0 && _closeTime > 0 && _startTime < _closeTime && block.timestamp < _closeTime,
            "FantiuyarnmClaimingV1: times must be greater than 0 and close time must be greater than start time and in the future"
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
            _tokenIds.length <= 100,
            "FantiumClaimingV1: Arrays must be of length <= 100"
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
        whenNotPaused
        onlyValidDistributionEvent(_distributionEventId)
    {
        // CHECKS

        // check if distribution Event was paid in in full 
        require(
            distributionEvents[_distributionEventId].amountPaidIn ==  (distributionEvents[_distributionEventId].tournamentDistributionAmount + distributionEvents[_distributionEventId].otherDistributionAmount),
            "FantiumClaimingV1: total distribution amount has not been paid in"
        );

        //check if _msgSender() has FAN token Id
        require(
            _msgSender() ==
                IERC721Upgradeable(fantiumNFTContract).ownerOf(_tokenId),
            "FantiumClaimingV1: Only token owner"
        );

        //check if _msgSender() is IDENTed
        require(
            isAddressIDENT(_msgSender()),
            "FantiumClaimingV1: You are not ID verified"
        );

        //check if lockTime is over or ca be ignored  
        require(
            distributionEvents[_distributionEventId].startTime <
                block.timestamp &&
                (distributionEvents[_distributionEventId].closeTime >
                block.timestamp || distributionEvents[_distributionEventId].closeTime == 0),
            "FantiumClaimingV1: distribution time has not started or has ended"
        );

        // check if distribution event is closed
        require(
            distributionEvents[_distributionEventId].closed == false,
            "FantiumClaimingV1: distribution event is closed"
        );

        //check if tokenID is valid and not to large
        require(
            _tokenId >= 1000000 && _tokenId <= 1000000000000,
            "FantiumClaimingV1: invalid token id"
        );

        // check if token is from a valid collection
        // check that hasn't claimed yet for that distribution event
        (uint256 collectionOfToken, , uint256 tokenNr) = TokenVersionUtil
            .getTokenInfo(_tokenId);
        uint256 baseTokenId = collectionOfToken * 1000000 + tokenNr;
        // check if token alreadu claimed 
        require(
            checkTokenAllowed(
                _distributionEventId,
                collectionOfToken,
                baseTokenId,
                tokenNr
            ),
            "FantiumClaimingV1: Token already claimed or Collection not allowed"
        );

        // EFFECTS
        //set claimed to true
        distributionEventToBaseTokenToClaimed[_distributionEventId][
            baseTokenId
        ] = true;

        //calculate claim amount
        uint256 claimAmount = calculateClaim(_distributionEventId, _tokenId);
        require(
            distributionEvents[_distributionEventId].claimedAmount +
                claimAmount <= distributionEvents[_distributionEventId].amountPaidIn,
            "FantiumClaimingV1: distribution amount exceeds payInAmount"
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

        (uint256 tournamentShare1e7, uint256 otherShare1e7) = IFantiumNFT(
            fantiumNFTContract
        ).getEarningsShares1e7(collectionOfToken);

        require(
            (tournamentShare1e7 > 0) ||
                (otherShare1e7 > 0),
            "FantiumClaimingV1: Token has no earnings"
        );
        // calculate amount to send
        // note: totalTorunamentEarnings = Total amount of earnings from tournaments
        // note: tournamentShare1e7 = % share of fan of total athlete earnings in 1e7 e.g. 0,00001% == 0,0000001 == 1
        // note: dividing by 1e7 to get the share in base 10  
        // note: Get the total distribution amount and multiple it by the token share and devide it by the overall share distributed
        // note: Example calculation for one token with 1% share: 100_000 USDC (amount) * 10.000.000(1e7)(share) / 1e7  = 1000 USDC
        uint256 tournamentClaim = ((distributionEvents[_distributionEventID].totalTournamentEarnings * tournamentShare1e7) /
            1e7);

        uint256 otherClaim = ((distributionEvents[_distributionEventID].totalOtherEarnings * otherShare1e7) / 1e7);

        return (tournamentClaim + otherClaim);
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
        tokenNrClaimed = distributionEventToBaseTokenToClaimed[
            _distributionEventID
        ][_baseTokenId];

        
        if(!tokenNrClaimed) {
        //check if collection is included in distribution event
        for (
            uint256 i = 0;
            i < distributionEvents[_distributionEventID].collectionIds.length;
            i++
        ) {
            // checking if the token is from a collection that is included in the distribution event
            if (
                distributionEvents[_distributionEventID].collectionIds[i] ==
                _collectionOfToken 
            ) {
                collectionIncluded = true;
                // check if tokenNr is in snapshot
                if (_tokenNr >= distributionEvents[_distributionEventID].mintedTokens[i]) {
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
            distributionEvent.fantiumFeeBPS) / 10000);

        // calculate user revenue
        uint256 userRevenue_ = _claimAmount - fantiumRevenue_;

        // set addresses from storage
        address fantiumAddress_ = distributionEvents[_distributionEventId]
            .fantiumFeeAddress;

        // FANtium payment
        if (fantiumRevenue_ > 0) {
            SafeERC20Upgradeable.safeTransfer(
                IERC20Upgradeable(payoutToken),
                fantiumAddress_,
                fantiumRevenue_
            );
        }
        // yser payment
        if (userRevenue_ > 0) {
            SafeERC20Upgradeable.safeTransfer(
                IERC20Upgradeable(payoutToken),
                _msgSender(),
                userRevenue_
            );
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN
    //////////////////////////////////////////////////////////////*/

    // take tokenSnapshot by platform manager
    function takeClaimingSnapshot(
        uint256 _distributionEventId
    ) external onlyRole(PLATFORM_MANAGER_ROLE) onlyValidDistributionEvent(_distributionEventId) {
    
    require(distributionEvents[_distributionEventId].collectionIds.length > 0 , "FantiumClaimingV1: no collections in distributionEvent");
    triggerClaimingSnapshot(_distributionEventId);
    }


    // automatic trigger for taking tokenSnapshot for claiming
    function triggerClaimingSnapshot(
        uint256 _distributionEventId
    ) internal onlyRole(PLATFORM_MANAGER_ROLE) 
    {
        
        // require(distributionEvents[_distributionEventId].collectionIds.length > 0 , "FantiumClaimingV1: no collections in distributionEvent");

        delete distributionEvents[_distributionEventId].mintedTokens;
        
        uint256 holdersTournamentEarningsShare1e7;
        uint256 holdersOtherEarningsShare1e7;

        for (uint256 i = 0; i < distributionEvents[_distributionEventId].collectionIds.length; i++) {

            uint24 maxTokenId = IFantiumNFT(fantiumNFTContract).getMintedTokensOfCollection(distributionEvents[_distributionEventId].collectionIds[i]);
            distributionEvents[_distributionEventId].mintedTokens.push(maxTokenId);

            (uint256 tournamentEarningShare1e7 , uint256 otherEarningShare1e7) = IFantiumNFT(fantiumNFTContract).getEarningsShares1e7(distributionEvents[_distributionEventId].collectionIds[i]);

            holdersTournamentEarningsShare1e7 += (maxTokenId * tournamentEarningShare1e7);
            holdersOtherEarningsShare1e7 += (maxTokenId * otherEarningShare1e7); 
        }

        distributionEvents[_distributionEventId].tournamentDistributionAmount = holdersTournamentEarningsShare1e7 * distributionEvents[_distributionEventId].totalTournamentEarnings / 1e7 ; 
        distributionEvents[_distributionEventId].otherDistributionAmount = holdersOtherEarningsShare1e7 * distributionEvents[_distributionEventId].totalOtherEarnings / 1e7; 

    }



    // update fantiumNFTContract address
    function updateFantiumNFTContract(
        address _fantiumNFTContract
    ) external onlyRole(PLATFORM_MANAGER_ROLE) {
        fantiumNFTContract = _fantiumNFTContract;
    }

    // update payoutToken address
    function updatePayoutToken(
        address _payoutToken
    ) external onlyRole(PLATFORM_MANAGER_ROLE) {
        require(
            IERC20Upgradeable(_payoutToken).balanceOf(address(this)) == 0,
            "FantiumClaimingV1: no balance"
        );
        payoutToken = _payoutToken;
    }

    // update payoutToken address
    function updateFantiumUserManager(
        address _fantiumUserManager
    ) external onlyRole(PLATFORM_MANAGER_ROLE) {
        fantiumUserManager = _fantiumUserManager;
    }

    function closeDistribution(
        uint256 _distributionEventId
    )
        external
        onlyRole(PLATFORM_MANAGER_ROLE)
        whenNotPaused
        onlyValidDistributionEvent(_distributionEventId)
    {
        require(
            distributionEvents[_distributionEventId].closed == false,
            "FantiumClaimingV1: distribution already closed"
        );

        // check if the athlete already paid it
        require(
            distributionEvents[_distributionEventId].amountPaidIn ==  distributionEvents[_distributionEventId].tournamentDistributionAmount + distributionEvents[_distributionEventId].otherDistributionAmount,
            "FantiumClaimingV1: Full amount not paid in yet"
        );

        // check if the athlete address is set
        require(
            distributionEvents[_distributionEventId].athleteAddress !=
                address(0),
            "FantiumClaimingV1: Athlete address not set yet"
        );

        distributionEvents[_distributionEventId].closed = true;
        uint256 closingAmount = distributionEvents[_distributionEventId].amountPaidIn - distributionEvents[_distributionEventId].claimedAmount;

        // check if the athlete address is set
        require(closingAmount > 0, "FantiumClaimingV1: Amount to pay is 0");

        SafeERC20Upgradeable.safeTransfer(
            IERC20Upgradeable(payoutToken),
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

    function setTrustedForwarder(
        address forwarder
    ) external onlyRole(UPGRADER_ROLE) {
        trustedForwarder = forwarder;
    }

    function isTrustedForwarder(
        address forwarder
    ) public view virtual returns (bool) {
        return forwarder == trustedForwarder;
    }

    function _msgSender()
        internal
        view
        virtual
        override
        returns (address sender)
    {
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

    function _msgData()
        internal
        view
        virtual
        override
        returns (bytes calldata)
    {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
}
