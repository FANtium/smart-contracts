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

/**
 * @title Claiming contract that allows payout tokens to be claimed
 * for FAN token holders.
 * @author MTX stuido AG.
 */

contract FantiumClaiming is 
    Initializable, 
    UUPSUpgradeable, 
    AccessControlUpgradeable, 
    PausableUpgradeable 
{
    IERC20 public payoutToken;

    FantiumNFTV4 public fantiumNFTContract;

    // mapping of distributionEvent to TokenID to claimed
    mapping(uint256 => DistributionEvent) public distributionEvents; 
    mapping(uint256 => mapping(uint256 => bool)) public distributionEventToTokenIdToClaimed;
    mapping(uint256 => uint256) public distributionEventIdToAmount;
    mapping(address => bool) public identedAddresses;

    uint256 private nextDistributionEventId;
    address public erc20PaymentToken;
    uint256 constant ONE_MILLION = 1_000_000;
    /// ACM
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE = keccak256("PLATFORM_MANAGER_ROLE");
    bytes32 public constant IDENT_MANAGER_ROLE = keccak256("IDENT_MANAGER_ROLE");

    struct DistributionEvent {
        uint256 distributionEventId;
        uint256[] collectionIds;
        uint256 amount;
        uint256 timestamp;
        bool exists;
    }


    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Claim(uint256 amount);
    event AddressAddedToIdent(address indexed _address);
    event AddressRemovedFromIdent(address indexed _address);



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

    modifier onlyIdentManager() {
        require(hasRole(IDENT_MANAGER_ROLE, msg.sender), "Only IDENT updater");
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
     * @notice Add address to IDENT list.
     * @param _address address to be added to IDENT list.
     */
    function addAddressToIdent(
        address _address
    ) external whenNotPaused onlyIdentManager {
        identedAddresses[_address] = true;
        emit AddressAddedToIDENT(_address);
    }

    /**
     * @notice Remove address from IDENT list.
     * @param _address address to be removed from IDENT list.
     */
    function removeAddressFromIdent(
        address _address
    ) 
    external 
    whenNotPaused 
    onlyIdentManager 
    {
        identedAddresses[_address] = false;
        emit AddressRemovedFromIDENT(_address);
    }

    /**
     * @notice Check if address is IDENTed.
     * @param _address address to be checked.
     * @return isIDENTed true if address is IDENTed.
     */
    function isAddressIDENTed(address _address) public view returns (bool) {
        return identedAddresses[_address];
    }

    /*///////////////////////////////////////////////////////////////
                            CLAIMING
    //////////////////////////////////////////////////////////////*/

    function claim(uint256 _tokenId) external {
        // CHECKS

        //check if msg.sender has FAN token Id
        require(
            msg.sender == fantiumNFTContract.ownerOf(_tokenId),
            "FantiumClaimingV1: You do not own this token"
        );

        //check if msg.sender is IDENTed
        // require(
        //     fantiumNFTContract.isAddressIDENTed(msg.sender),
        //     "FantiumClaimingV1: You are not IDENTed"
        // );

        //check if payouts were claimed for this token
        require(
            balances[_tokenId] > 0,
            "FantiumClaimingV1: payout has already been claimed"
        );

        //check if lockTime is over
        //require(fantiumNFTContract.getLockTimeForToken(_tokenId) < block.timestamp, "FantiumClaimingV1: lock time has not passed yet");

        // EFFECTS
        uint256 balanceToSend = balances[_tokenId];
        balances[_tokenId] = 0;

        // INTERACTIONS
        //transfer USDC to msg.sender
        payoutToken.transfer(msg.sender, balanceToSend);
    }

    /*///////////////////////////////////////////////////////////////
                            PAY
    //////////////////////////////////////////////////////////////*/

    function setupDistributionEvent(uint256 _amount, uint256[] _collectionIDs, ) external {
        // CHECKS

        

        // EFFECTS
        balances[_tokenId] = balances[_tokenId] + _amount;
    }

    function addTournamentEarnings(uint256 _tokenId, uint256 _amount) external {
    // CHECKS

    // check if _tokenId exists
    require(
        fantiumNFTContract.exists(_tokenId),
        "FantiumClaimingV1: Token does not exist"
    );

    // check if msg.sender is the collection's athlete
    require(
        msg.sender ==
            fantiumNFTContract
                .getCollectionForTokenId(_tokenId)
                .athleteAddress,
        "FantiumClaimingV1: You are not FantiumNFT contract"
    );
    
    require(payoutToken.transferFrom(msg.sender, address(this), _amount), "FantiumClaimingV1: transferFrom failed");

    // EFFECTS
    balances[_tokenId] = balances[_tokenId] + _amount;
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN
    //////////////////////////////////////////////////////////////*/

    // update fantiumNFTContract address
    function updateFantiumNFTContract(address _fantiumNFTContract)
        external
        onlyOwner
    {
        fantiumNFTContract = FantiumNFTV4(_fantiumNFTContract);
    }

    // update payoutToken address
    function updatePayoutToken(address _payoutToken) external onlyOwner {
        payoutToken = ERC20(_payoutToken);
    }
}
