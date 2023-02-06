// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "../FantiumNFTV4.sol";
import "../utils/FantiumUserManager.sol";
import "../utils/TokenVersionUtil.sol";

/**
 * @title Claiming contract that allows payout tokens to be claimed
 * for FAN token holders.
 * @author MTX studoi AG.
 */

contract FantiumClaiming is
    Initializable, 
    UUPSUpgradeable, 
    AccessControlUpgradeable, 
    PausableUpgradeable 
{
     
    IERC20 public payoutToken;

    FantiumNFTV4 public fantiumNFTContract;
    FantiumUserManager public fantiumUserManager;

    // mapping of distributionEvent to TokenID to claimed
    mapping(uint256 => DistributionEvent) public distributionEvents; 
    mapping(uint256 => mapping(uint256 => bool)) public distributionEventToTokenIdToClaimed;
    mapping(address => bool) public identedAddresses;

    uint256 private nextDistributionEventId;
    address public erc20PaymentToken;
    uint256 constant ONE_MILLION = 1_000_000;
    /// ACM
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE = keccak256("PLATFORM_MANAGER_ROLE");

    struct DistributionEvent {
        uint256 distributionEventId;
        uint256[9] collectionIds;
        address athleteAddress;
        uint256 amount;
        uint256 distributedAmount;
        uint256 startTime;
        bool exists;
        bool closed;
    }


    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Claim(uint256 amount);


    /*//////////////////////////////////////////////////////////////
                            MODIFERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAthlete(uint256 _distributionEventId) {
        require(
            msg.sender == distributionEvents[_distributionEventId].athleteAddress ||
                hasRole(PLATFORM_MANAGER_ROLE, msg.sender),
            "Only athlete"
        );
        _;
    }

    modifier onlyManager() {
        require(hasRole(PLATFORM_MANAGER_ROLE, msg.sender),
            "Only athlete"
        );
        _;
    }

    modifier onlyTokenOwner(uint256 _tokenId) {
        require(fantiumNFTContract.ownerOf(_tokenId) == msg.sender,
            "Invalid tokenId"
        );
        _;
    }

    modifier onlyValidAddress(address _address) {
        require(_address != address(0), "Invalid address");
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
    function initialize(address _payoutToken, address _fantiumNFTContract, address _defaultAdmin)
        public
        initializer
    {
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
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                                 IDENT
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
                            CLAIMING
    //////////////////////////////////////////////////////////////*/

    function claim(uint256 _tokenId, uint256 _distributionEventID) 
    external 
    onlyTokenOwner(_tokenId)
    whenNotPaused
    {
        // CHECKS

        //check if msg.sender has FAN token Id
        require(
            msg.sender == fantiumNFTContract.ownerOf(_tokenId),
            "FantiumClaimingV1: You do not own this token"
        );

        //check if msg.sender is IDENTed
        require(
            isAddressIDENT(msg.sender),
            "FantiumClaimingV1: You are not IDENTed"
        );

        //check if lockTime is over
        require(distributionEvents[_distributionEventID].startTime  < block.timestamp, "FantiumClaimingV1: distribution time has not started");
        
        //check if tokenID is valid and not to large
        require(_tokenId >= 1000000 && _tokenId <= 100000000000 , "FantiumClaimingV1: invalid token id");

        // check if token is from a valid collection
        // check that hasn't claimed yet for that distribution event
        (uint256 collectionOfToken,,uint256 tokenNr) =  TokenVersionUtil.getTokenInfo(_tokenId);
        uint256 baseTokenId = collectionOfToken * 1000000 + tokenNr;
        require(checkTokenAllowed(_distributionEventID, collectionOfToken ,baseTokenId), "FantiumClaimingV1: Token already claimed or Collection not allowed");
        
        // EFFECTS
        //set claimed to true 
        distributionEventToTokenIdToClaimed[_distributionEventID][baseTokenId] == true;
        
        //calculate claim amount
        uint256 claimAmount = calculateClaim(_distributionEventID, _tokenId);
        require( distributionEvents[_distributionEventID].distributedAmount + claimAmount <= distributionEvents[_distributionEventID].amount, "FantiumClaimingV1: distribution amount exceeded" );
        distributionEvents[_distributionEventID].distributedAmount += claimAmount;

        // INTERACTIONS
        //transfer USDC to msg.sender
        require(fantiumNFTContract.upgradeTokenVersion(_tokenId), "FantiumClaimingV1: upgrade failed");
        require(payoutToken.transferFrom(address(this),msg.sender, claimAmount), "FantiumClaimingV1: transfer failed");
        //upgrade token to new version
        
    }

    /*///////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    // 
    function setupDistributionEvent(
        address _athleteAddress, 
        uint256 _amount, 
        uint256 startTime, 
        uint256[9] memory _collectionIds)
    external 
    onlyManager
    whenNotPaused
    onlyValidAddress(_athleteAddress)
    {
        // CHECKS
        require(_amount > 0, "FantiumClaimingV1: amount must be greater than 0");
        require(startTime > 0, "FantiumClaimingV1: start time must be greater than 0");
        require(_collectionIds.length > 0, "FantiumClaimingV1: collectionIds must be greater than 0");
        require(_amount < 1000000000, "FantiumClaimingV1: amount must be less than a billion");
        
        //check if collection exists
        for (uint256 i = 0; i < _collectionIds.length; i++) {
            bool collectionExists = fantiumNFTContract.getCollection(_collectionIds[i]).exists;
            require(collectionExists , "FantiumClaimingV1: collection does not exist");
        } 
        // EFFECTS
        DistributionEvent memory  distributionEvent;
        distributionEvent.distributionEventId = nextDistributionEventId;
        distributionEvent.amount = _amount;
        distributionEvent.collectionIds = _collectionIds;
        distributionEvent.athleteAddress = _athleteAddress;
        distributionEvent.startTime = startTime;
        distributionEvent.exists = true;
        distributionEvent.closed = false;
        distributionEvents[nextDistributionEventId] = distributionEvent;
        nextDistributionEventId++;
    }


    function addDistributionAmount(uint256 _distributionEventId, uint256 _amount) 
    external 
    whenNotPaused 
    onlyAthlete(_distributionEventId){
    // CHECKS
    require(distributionEvents[_distributionEventId].exists, "FantiumClaimingV1: distributionEventId does not exist");
    require(_amount == distributionEvents[_distributionEventId].amount, "FantiumClaimingV1: amount must be equal to distribution amount");
    
    // EFFECTS
    distributionEvents[_distributionEventId].amount = distributionEvents[_distributionEventId].amount + _amount ;
    payoutToken.transferFrom(msg.sender, address(this), _amount);
    }
    

    /*///////////////////////////////////////////////////////////////
                            INTERNAL 
    //////////////////////////////////////////////////////////////*/


    // calcualtes the amount to send to the user
    function calculateClaim(uint256 _distributionEventID,uint256  _tokenId) view internal returns (uint256){
        (uint256 collectionOfToken,,) =  TokenVersionUtil.getTokenInfo(_tokenId);
        
        uint256 share =  fantiumNFTContract.getCollection(collectionOfToken).tournamentEarningShare1e7;
        // calculate amount to send
        // note: divice by 1e7 will always down round amount at decimal
        uint256 claimAmount = distributionEvents[_distributionEventID].amount * share / 1e7;
        return (claimAmount);
    }

    // check if token is from a valid collection and hasn't claimed yet for that distribution event    
    function checkTokenAllowed(uint256 _distributionEventID,  uint256 _collectionOfToken, uint256 _baseTokenId) view internal returns (bool){
        bool collectionIncluded = false;
        bool tokenNrIncluded = false; 
        /////// still need figuring out how to make sure that a token cannot be double spend --> use token without version as base for it ////// 

        //check if payouts were claimed for this token
        if(distributionEventToTokenIdToClaimed[_distributionEventID][_baseTokenId] == true){
                tokenNrIncluded = true;
        }

        for (uint256 i = 0; i < distributionEvents[_distributionEventID].collectionIds.length; i++) {
            if (distributionEvents[_distributionEventID].collectionIds[i] == _collectionOfToken){
                collectionIncluded = true;}
            }
        
        if (collectionIncluded && tokenNrIncluded) {
            return true;
        } else {
            return false;
        }
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN
    //////////////////////////////////////////////////////////////*/

    // update fantiumNFTContract address
    function updateFantiumNFTContract(address _fantiumNFTContract)
        external
        onlyManager
    {
        fantiumNFTContract = FantiumNFTV4(_fantiumNFTContract);
    }

    // update payoutToken address
    function updatePayoutToken(address _payoutToken) 
    external
    onlyManager {
        payoutToken = ERC20(_payoutToken);
    }

    function closeDistribution(uint256 _distributionEventId) external onlyManager {

        distributionEvents[_distributionEventId].closed = true;
    }


}