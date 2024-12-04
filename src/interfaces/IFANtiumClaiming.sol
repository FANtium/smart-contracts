// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev CAUTION: This struct is used to store the distribution event information.
 * Since it is used in the upgradeable contract, do not change the order of the fields.
 */
struct DistributionEvent {
    uint256 distributionEventId;
    /// @notice NFT collections allowed to claim
    uint256[] collectionIds;
    /// @notice athlete address that need to pay in amount
    address payable athleteAddress;
    /// @notice total earnings from tournaments with decimals
    uint256 totalTournamentEarnings;
    /// @notice total earnings from other sources with decimals
    uint256 totalOtherEarnings;
    /// @notice total earnings to be distributed from tournaments with decimals
    uint256 tournamentDistributionAmount;
    /// @notice total earnings to be distributed from other sources with decimals
    uint256 otherDistributionAmount;
    /// @notice amount has been paid in
    uint256 amountPaidIn;
    /// @notice total amount claimed so far
    uint256 claimedAmount;
    /// @notice fantium fee in basis points
    uint256 fantiumFeeBPS;
    /// @notice fantium fee address
    address payable fantiumFeeAddress;
    /// @notice start time of distribution event (can be 0 if it starts immediately)
    uint256 startTime;
    /// @notice close time of distribution event (can be 0 if it never closes)
    uint256 closeTime;
    /// @notice if the distribution event exists
    bool exists;
    /// @notice if the distribution event is closed
    bool closed;
}

struct DistributionEventData {
    address payable athleteAddress;
    uint256 totalTournamentEarnings;
    uint256 totalOtherEarnings;
    uint256 startTime;
    uint256 closeTime;
    uint256[] collectionIds;
    address payable fantiumAddress;
    uint256 fantiumFeeBPS;
}

/**
 * @dev CAUTION: This struct is used to store the collection information.
 * Since it is used in the upgradeable contract, do not change the order of the fields.
 */
struct CollectionInfo {
    uint256 mintedTokens;
    uint256 tokenTournamentClaim;
    uint256 tokenOtherClaim;
}

enum DistributionEventErrorReason {
    INVALID_TIME,
    INVALID_COLLECTION_IDS,
    INVALID_FANTIUM_FEE_BPS,
    INVALID_ADDRESS,
    INVALID_AMOUNT,
    ALREADY_CLOSED,
    PAYOUTS_STARTED
}

enum DistributionEventFundingErrorReason {
    CLOSED,
    INVALID_AMOUNT,
    FUNDING_ALREADY_DONE
}

enum DistributionEventCloseErrorReason {
    DISTRIBUTION_ALREADY_CLOSED,
    ATHLETE_ADDRESS_NOT_SET
}

enum ClaimErrorReason {
    INVALID_AMOUNT,
    NOT_FULLY_PAID_IN,
    ONLY_TOKEN_OWNER,
    NOT_IDENTED,
    INVALID_TIME_FRAME,
    NOT_ELIGIBLE,
    INVARIANT_EXCEED_PAID_IN
}

interface IFANtiumClaiming {
    // ========================================================================
    // Events
    // ========================================================================
    event Claim(uint256 indexed _distributionEventId, uint256 indexed _tokenId, uint256 amount);
    event DistributionEventUpdate(uint256 indexed _distributionEventId, bytes32 indexed _field);
    event PayIn(uint256 indexed _distributionEventId, uint256 amount);
    event SnapShotTaken(uint256 indexed _distributionEventId);
    event PlatformUpdate(bytes32 indexed _update);

    // ========================================================================
    // Errors
    // ========================================================================
    error InvariantTransferFailed(address token, address from, address to, uint256 amount);
    error InvalidDistributionEventId(uint256 distributionEventId);
    error InvalidDistributionEvent(DistributionEventErrorReason reason);
    error InvalidDistributionEventFunding(DistributionEventFundingErrorReason reason);
    error InvalidDistributionEventClose(DistributionEventCloseErrorReason reason);
    error InvalidClaim(ClaimErrorReason reason);
    error AthleteOnly(uint256 distributionEventId, address account, address expected);

    // ========================================================================
    // Distribution Event
    // ========================================================================
    function createDistributionEvent(DistributionEventData memory data) external;
    function updateDistributionEvent(uint256 distributionEventId, DistributionEventData memory data) external;
    function fundDistributionEvent(uint256 distributionEventId) external;
    function batchFundDistributionEvent(uint256[] memory distributionEventIds) external;
    function closeDistribution(uint256 distributionEventId) external;

    // ========================================================================
    // Claiming
    // ========================================================================
    function claim(uint256 tokenId, uint256 distributionEventId) external;
    function batchClaim(uint256[] memory tokenIds, uint256[] memory distributionEventIds) external;
    function takeClaimingSnapshot(uint256 distributionEventId) external;
}
