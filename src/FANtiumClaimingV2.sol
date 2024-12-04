// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IFANtiumNFT, Collection } from "src/interfaces/IFANtiumNFT.sol";
import {
    IFANtiumClaiming,
    DistributionEvent,
    DistributionEventData,
    DistributionEventErrorReason,
    DistributionEventFundingErrorReason,
    DistributionEventCloseErrorReason,
    ClaimErrorReason,
    CollectionInfo
} from "src/interfaces/IFANtiumClaiming.sol";
import { IFANtiumUserManager } from "src/interfaces/IFANtiumUserManager.sol";
import { TokenVersionUtil } from "src/utils/TokenVersionUtil.sol";
import { FANtiumBaseUpgradable } from "src/FANtiumBaseUpgradable.sol";

/**
 * @title FANtium Claining contract V2.
 * @notice This contract is used to manage distribution events and claim payouts for FAN token holders.
 * @author Mathieu Bour - FANtium AG, based on previous work by MTX studio AG.
 */
contract FANtiumClaimingV2 is FANtiumBaseUpgradable, IFANtiumClaiming {
    using SafeERC20 for IERC20;

    // ========================================================================
    // State variables
    // ========================================================================
    address public globalPayoutToken;
    address private UNUSED_trustedForwarder; // Now handled by the FANtiumBaseUpgradable contract
    IFANtiumNFT public fantiumNFT;
    IFANtiumUserManager public fantiumUserManager;

    /**
     * @dev mapping of distributionEvent to DistributionEvent
     * Distribution Event ID -> Distribution Event
     */
    mapping(uint256 => DistributionEvent) private _distributionEvents;

    /**
     * @notice mapping of distributionEvent to baseTokenId to claimed
     * Distribution Event ID -> Base Token ID (token with version=0) -> Claimed
     */
    mapping(uint256 => mapping(uint256 => bool)) private _distributionEventToBaseTokenToClaimed;

    /**
     * @notice mapping of distributionEvent to collectionId to CollectionInfo
     * Distribution Event ID -> Collection ID -> Collection Info
     */
    mapping(uint256 => mapping(uint256 => CollectionInfo)) private _distributionEventToCollectionInfo;

    /**
     * @notice mapping of distributionEvent to payout token
     * Distribution Event ID -> Payout Token (IERC20)
     */
    mapping(uint256 => IERC20) private _distributionEventToPayoutToken;

    uint256 private nextDistributionEventId;

    // ========================================================================
    // UUPS upgradeable pattern
    // ========================================================================
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        // _disableInitializers(); // TODO: uncomment when we are on v6
    }

    function initialize(address admin) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        nextDistributionEventId = 1;
    }

    function version() public pure override returns (string memory) {
        return "2.0.0";
    }

    // ========================================================================
    // Modifiers
    // ========================================================================
    modifier onlyAthlete(uint256 distributionEventId) {
        if (_msgSender() != _distributionEvents[distributionEventId].athleteAddress) {
            revert AthleteOnly(distributionEventId, msg.sender, _distributionEvents[distributionEventId].athleteAddress);
        }
        _;
    }

    /**
     * @dev Modifier to check if the sender is the athlete, a manager or an admin.
     * @param distributionEventId The ID of the distribution event
     */
    modifier onlyAthleteOrManagerOrAdmin(uint256 distributionEventId) {
        if (
            _msgSender() != _distributionEvents[distributionEventId].athleteAddress
                && !hasRole(MANAGER_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
        ) {
            revert AthleteOnly(distributionEventId, msg.sender, _distributionEvents[distributionEventId].athleteAddress);
        }
        _;
    }

    modifier onlyValidDistributionEvent(uint256 distributionEventId) {
        if (!_distributionEvents[distributionEventId].exists) {
            revert InvalidDistributionEventId(distributionEventId);
        }
        _;
    }

    // ========================================================================
    // Setters
    // ========================================================================
    function setFantiumNFT(IFANtiumNFT _fantiumNFT) external onlyManagerOrAdmin {
        fantiumNFT = _fantiumNFT;
    }

    function setUserManager(IFANtiumUserManager _fantiumUserManager) external onlyManagerOrAdmin {
        fantiumUserManager = _fantiumUserManager;
    }

    function setGlobalPayoutToken(address _globalPayoutToken) external onlyManagerOrAdmin {
        globalPayoutToken = _globalPayoutToken;
    }

    // ========================================================================
    // Distribution event        functions
    // ========================================================================
    function distributionEvents(uint256 distributionEventId) public view returns (DistributionEvent memory) {
        return _distributionEvents[distributionEventId];
    }

    function _checkDistributionEvent(DistributionEventData memory data) private view {
        // Check if the provided times are valid
        if (
            data.startTime == 0 || data.closeTime == 0 || data.startTime > data.closeTime
                || block.timestamp > data.closeTime
        ) {
            revert InvalidDistributionEvent(DistributionEventErrorReason.INVALID_TIME);
        }

        // At least one collection is required
        if (data.collectionIds.length == 0) {
            revert InvalidDistributionEvent(DistributionEventErrorReason.INVALID_COLLECTION_IDS);
        }

        // Ensure all collections exist
        for (uint256 i = 0; i < data.collectionIds.length; i++) {
            if (!IFANtiumNFT(fantiumNFT).collections(data.collectionIds[i]).exists) {
                revert InvalidDistributionEvent(DistributionEventErrorReason.INVALID_COLLECTION_IDS);
            }
        }

        if (data.fantiumFeeBPS >= 10_000) {
            revert InvalidDistributionEvent(DistributionEventErrorReason.INVALID_FANTIUM_FEE_BPS);
        }

        if (data.athleteAddress == address(0) || data.fantiumAddress == address(0)) {
            revert InvalidDistributionEvent(DistributionEventErrorReason.INVALID_ADDRESS);
        }

        // Even in our greatest dreams, we will never pay out more than a billion
        uint256 maxAmount = 1_000_000_000 * 10 ** IERC20Metadata(globalPayoutToken).decimals();
        uint256 sum = data.totalTournamentEarnings + data.totalOtherEarnings;

        if (sum == 0 || sum >= maxAmount) {
            revert InvalidDistributionEvent(DistributionEventErrorReason.INVALID_AMOUNT);
        }
    }

    function _checkDistributionNotStarted(uint256 distributionEventId) private view {
        if (_distributionEvents[distributionEventId].claimedAmount > 0) {
            revert InvalidDistributionEvent(DistributionEventErrorReason.PAYOUTS_STARTED);
        }
    }

    function createDistributionEvent(DistributionEventData memory data) external onlyManagerOrAdmin whenNotPaused {
        _checkDistributionEvent(data);

        uint256 distributionEventId = nextDistributionEventId++;
        DistributionEvent memory newDistributionEvent = DistributionEvent({
            distributionEventId: distributionEventId,
            collectionIds: data.collectionIds,
            athleteAddress: data.athleteAddress,
            totalTournamentEarnings: data.totalTournamentEarnings,
            totalOtherEarnings: data.totalOtherEarnings,
            tournamentDistributionAmount: 0,
            otherDistributionAmount: 0,
            amountPaidIn: 0,
            claimedAmount: 0,
            fantiumFeeBPS: data.fantiumFeeBPS,
            fantiumFeeAddress: data.fantiumAddress,
            startTime: data.startTime,
            closeTime: data.closeTime,
            exists: true,
            closed: false
        });
        _distributionEvents[distributionEventId] = newDistributionEvent;

        _distributionEventToPayoutToken[distributionEventId] = IERC20(globalPayoutToken);
        _recomputeClaimShares(distributionEventId);
    }

    function updateDistributionEvent(
        uint256 distributionEventId,
        DistributionEventData memory data
    )
        external
        onlyManagerOrAdmin
        onlyValidDistributionEvent(distributionEventId)
    {
        _checkDistributionEvent(data);

        DistributionEvent memory existingDE = _distributionEvents[distributionEventId];

        // Check if the distribution event is closed
        if (existingDE.closed) {
            revert InvalidDistributionEvent(DistributionEventErrorReason.ALREADY_CLOSED);
        }

        bool collectionIdsChanged = data.collectionIds.length != existingDE.collectionIds.length;
        if (!collectionIdsChanged) {
            for (uint256 i = 0; i < data.collectionIds.length; i++) {
                if (data.collectionIds[i] != existingDE.collectionIds[i]) {
                    collectionIdsChanged = true;
                    break;
                }
            }
        }

        // earnings, fee, collectionIds may only be updated before the distribution event has started
        if (
            data.totalTournamentEarnings != existingDE.totalTournamentEarnings
                || data.totalOtherEarnings != existingDE.totalOtherEarnings || collectionIdsChanged
                || data.fantiumFeeBPS != existingDE.fantiumFeeBPS
        ) {
            // Earnings are updated - some extra checks are needed
            _checkDistributionNotStarted(distributionEventId);
        }

        existingDE.collectionIds = data.collectionIds;
        existingDE.athleteAddress = data.athleteAddress;
        existingDE.totalTournamentEarnings = data.totalTournamentEarnings;
        existingDE.totalOtherEarnings = data.totalOtherEarnings;
        existingDE.fantiumFeeAddress = data.fantiumAddress;
        existingDE.fantiumFeeBPS = data.fantiumFeeBPS;
        existingDE.startTime = data.startTime;
        existingDE.closeTime = data.closeTime;

        _distributionEvents[distributionEventId] = existingDE;
        _recomputeClaimShares(distributionEventId);

        DistributionEvent memory updatedDE = _distributionEvents[distributionEventId];
        if (updatedDE.tournamentDistributionAmount + updatedDE.otherDistributionAmount > updatedDE.amountPaidIn) {
            revert InvalidDistributionEvent(DistributionEventErrorReason.INVALID_AMOUNT);
        }
    }

    /**
     * @notice Pay the distribution amount for a distribution event.
     * @param distributionEventId The ID of the distribution event
     */
    function fundDistributionEvent(uint256 distributionEventId)
        public
        whenNotPaused
        onlyValidDistributionEvent(distributionEventId)
        onlyAthlete(distributionEventId)
    {
        DistributionEvent memory existingDE = _distributionEvents[distributionEventId];

        // check that the distribution event is open
        if (existingDE.closed) {
            revert InvalidDistributionEventFunding(DistributionEventFundingErrorReason.CLOSED);
        }

        uint256 totalAmount = existingDE.tournamentDistributionAmount + existingDE.otherDistributionAmount;
        uint256 missingAmount = totalAmount - existingDE.amountPaidIn;

        if (missingAmount == 0) {
            revert InvalidDistributionEventFunding(DistributionEventFundingErrorReason.FUNDING_ALREADY_DONE);
        }

        // Take the missing amount from the sender
        IERC20 token = _distributionEventToPayoutToken[distributionEventId];
        token.safeTransferFrom(_msgSender(), address(this), missingAmount);

        existingDE.amountPaidIn += missingAmount;
        _distributionEvents[distributionEventId] = existingDE;
        emit PayIn(distributionEventId, missingAmount);
    }

    /**
     * @notice Batch fund distribution events.
     * @dev No modifier is needed here since the caller is already checked for being the athlete.
     * @param distributionEventIds The IDs of the distribution events
     */
    function batchFundDistributionEvent(uint256[] memory distributionEventIds) external {
        for (uint256 i = 0; i < distributionEventIds.length; i++) {
            fundDistributionEvent(distributionEventIds[i]);
        }
    }

    /**
     * @notice Close a distribution event, sending the remaining funds to the athlete.
     * @param distributionEventId The ID of the distribution event
     */
    function closeDistribution(uint256 distributionEventId)
        external
        whenNotPaused
        onlyManagerOrAdmin
        onlyValidDistributionEvent(distributionEventId)
    {
        DistributionEvent memory existingDE = _distributionEvents[distributionEventId];
        if (existingDE.closed) {
            revert InvalidDistributionEventClose(DistributionEventCloseErrorReason.DISTRIBUTION_ALREADY_CLOSED);
        }

        if (existingDE.athleteAddress == address(0)) {
            revert InvalidDistributionEventClose(DistributionEventCloseErrorReason.ATHLETE_ADDRESS_NOT_SET);
        }

        existingDE.closed = true;
        uint256 closingAmount = existingDE.amountPaidIn - existingDE.claimedAmount;

        if (closingAmount == 0) {
            return;
        }

        IERC20 payOutToken = _distributionEventToPayoutToken[distributionEventId];
        payOutToken.safeTransfer(existingDE.athleteAddress, closingAmount);
    }

    // ========================================================================
    // Claiming
    // ========================================================================
    /**
     * @notice To be eligiblem for a claim, a token:
     * - must be part of one of the collections included in the distribution event
     * - is number must be in the snapshot, e.g. it must have been minted before the distribution event started
     * - must not have been claimed yet for that distribution event
     */
    function isEligibleForClaim(uint256 distributionEventId, uint256 tokenId) public view returns (bool) {
        DistributionEvent memory existingDE = _distributionEvents[distributionEventId];
        (uint256 collectionId,, uint256 number, uint256 baseTokenId) = TokenVersionUtil.getTokenInfo(tokenId);

        // Check if the token is from a valid collection
        bool collectionOK;
        for (uint256 i = 0; i < existingDE.collectionIds.length; i++) {
            if (existingDE.collectionIds[i] == collectionId) {
                collectionOK = true;
                break;
            }
        }

        if (!collectionOK) {
            return false;
        }

        // Now, checkk if the token was minted before the distribution event started
        if (number >= _distributionEventToCollectionInfo[distributionEventId][collectionId].mintedTokens) {
            return false;
        }

        // Finally, check if the token has already been claimed for this distribution event
        return !_distributionEventToBaseTokenToClaimed[distributionEventId][baseTokenId];
    }

    /**
     * @notice Claim for a single token.
     * @param tokenId The ID of the token
     * @param distributionEventId The ID of the distribution event
     */
    function claim(
        uint256 tokenId,
        uint256 distributionEventId
    )
        public
        whenNotPaused
        onlyValidDistributionEvent(distributionEventId)
    {
        DistributionEvent memory existingDE = _distributionEvents[distributionEventId];
        if (existingDE.closed) {
            revert InvalidDistributionEventClose(DistributionEventCloseErrorReason.DISTRIBUTION_ALREADY_CLOSED);
        }

        if (existingDE.amountPaidIn < existingDE.tournamentDistributionAmount + existingDE.otherDistributionAmount) {
            revert InvalidClaim(ClaimErrorReason.NOT_FULLY_PAID_IN);
        }

        if (_msgSender() != fantiumNFT.ownerOf(tokenId)) {
            revert InvalidClaim(ClaimErrorReason.ONLY_TOKEN_OWNER);
        }

        if (!fantiumUserManager.isIDENT(_msgSender())) {
            revert InvalidClaim(ClaimErrorReason.NOT_IDENTED);
        }

        if (existingDE.startTime >= block.timestamp || existingDE.closeTime <= block.timestamp) {
            revert InvalidClaim(ClaimErrorReason.INVALID_TIME_FRAME);
        }

        if (!isEligibleForClaim(distributionEventId, tokenId)) {
            revert InvalidClaim(ClaimErrorReason.NOT_ELIGIBLE);
        }

        // Mark the token as claimed
        (uint256 collectionId,,, uint256 baseTokenId) = TokenVersionUtil.getTokenInfo(tokenId);
        _distributionEventToBaseTokenToClaimed[distributionEventId][baseTokenId] = true;

        // Compute the claim amount
        CollectionInfo memory collectionInfo = _distributionEventToCollectionInfo[distributionEventId][collectionId];
        uint256 claimAmount = collectionInfo.tokenTournamentClaim + collectionInfo.tokenOtherClaim;

        if (existingDE.claimedAmount + claimAmount > existingDE.amountPaidIn) {
            revert InvalidClaim(ClaimErrorReason.INVARIANT_EXCEED_PAID_IN);
        }
        _distributionEvents[distributionEventId].claimedAmount += claimAmount;

        // Upgrade the token version
        fantiumNFT.upgradeTokenVersion(tokenId);

        // Split the claim amount between FANtium and the user
        uint256 fantiumRevenue_ = ((claimAmount * existingDE.fantiumFeeBPS) / 10_000);
        uint256 userRevenue_ = claimAmount - fantiumRevenue_;

        // set addresses from storage
        address fantiumAddress_ = existingDE.fantiumFeeAddress;
        IERC20 payOutToken = _distributionEventToPayoutToken[distributionEventId];

        if (fantiumRevenue_ > 0) {
            payOutToken.safeTransfer(fantiumAddress_, fantiumRevenue_);
        }
        if (userRevenue_ > 0) {
            payOutToken.safeTransfer(_msgSender(), userRevenue_);
        }

        emit Claim(distributionEventId, tokenId, claimAmount);
    }

    /**
     * @notice Batch claim for multiple tokens.
     * @param tokenIds The IDs of the tokens
     * @param distributionEventIds The IDs of the distribution events
     */
    function batchClaim(uint256[] memory tokenIds, uint256[] memory distributionEventIds) external whenNotPaused {
        if (tokenIds.length != distributionEventIds.length) {
            revert ArrayLengthMismatch(tokenIds.length, distributionEventIds.length);
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            claim(tokenIds[i], distributionEventIds[i]);
        }
    }

    /**
     * @dev Given a distribution event ID, a token's share of tournament earnings and a token's share of other earnings,
     * this function calculates the amount to send to the user.
     * @param distributionEventId The ID of the distribution event
     * @param tournamentEarningsShare1e7 The share of tournament earnings in 1e7
     * @param otherEarningShare1e7 The share of other earnings in 1e7
     * @return tournamentClaim The amount to send to the user for tournament earnings
     * @return otherClaim The amount to send to the user for other earnings
     */
    function computeShares(
        uint256 distributionEventId,
        uint256 tournamentEarningsShare1e7,
        uint256 otherEarningShare1e7
    )
        internal
        view
        returns (uint256 tournamentClaim, uint256 otherClaim)
    {
        require(
            (tournamentEarningsShare1e7 > 0) || (otherEarningShare1e7 > 0), "FANtiumClaimingV1: Token has no earnings"
        );

        DistributionEvent memory distributionEvent = _distributionEvents[distributionEventId];
        tournamentClaim = ((distributionEvent.totalTournamentEarnings * tournamentEarningsShare1e7) / 1e7);
        otherClaim = ((distributionEvent.totalOtherEarnings * otherEarningShare1e7) / 1e7);
    }

    /**
     * @dev Triggers the claiming snapshot for a distribution event.
     * Can only be run once per distribution event.
     * @param distributionEventId The ID of the distribution event
     */
    function _recomputeClaimShares(uint256 distributionEventId) internal {
        DistributionEvent memory distributionEvent = _distributionEvents[distributionEventId];

        // Sum of all the holders' tournament and other earnings shares in 1e7
        uint256 holdersTournamentEarningsShare1e7;
        uint256 holdersOtherEarningsShare1e7;

        for (uint256 i = 0; i < distributionEvent.collectionIds.length; i++) {
            uint256 collectionId = distributionEvent.collectionIds[i];
            Collection memory collection = fantiumNFT.collections(collectionId);

            // Compute the token's share of tournament and other earnings
            (uint256 tournamentClaim, uint256 otherClaim) = computeShares(
                distributionEventId, collection.tournamentEarningShare1e7, collection.otherEarningShare1e7
            );

            _distributionEventToCollectionInfo[distributionEventId][collectionId] = CollectionInfo({
                mintedTokens: collection.invocations,
                tokenTournamentClaim: tournamentClaim,
                tokenOtherClaim: otherClaim
            });

            // Increment the sum of all the holders' tournament and other earnings shares in 1e7
            holdersTournamentEarningsShare1e7 += (collection.invocations * collection.tournamentEarningShare1e7);
            holdersOtherEarningsShare1e7 += (collection.invocations * collection.otherEarningShare1e7);
        }

        // Calculate the tournament and other distribution amounts
        distributionEvent.tournamentDistributionAmount =
            (holdersTournamentEarningsShare1e7 * distributionEvent.totalTournamentEarnings) / 1e7;
        distributionEvent.otherDistributionAmount =
            (holdersOtherEarningsShare1e7 * distributionEvent.totalOtherEarnings) / 1e7;

        _distributionEvents[distributionEventId] = distributionEvent;
    }

    /**
     * @dev Triggers the claiming snapshot for a distribution event.
     * Can only be run once per distribution event.
     * @param distributionEventId The ID of the distribution event
     */
    function takeClaimingSnapshot(uint256 distributionEventId)
        external
        onlyManagerOrAdmin
        onlyValidDistributionEvent(distributionEventId)
    {
        _recomputeClaimShares(distributionEventId);
        emit SnapShotTaken(distributionEventId);
    }
}
