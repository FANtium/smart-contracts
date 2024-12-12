// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev CAUTION: This struct is used to store the distribution information.
 * Since it is used in the upgradeable contract, do not change the order of the fields.
 */
struct Distribution {
    /**
     * @custom:oz-renamed-from distributionEventId
     */
    uint256 distributionId;
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
    /// @notice start time of distribution (can be 0 if it starts immediately)
    uint256 startTime;
    /// @notice close time of distribution (can be 0 if it never closes)
    uint256 closeTime;
    /// @notice if the distribution exists
    bool exists;
    /// @notice if the distribution is closed
    bool closed;
}

struct DistributionData {
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

enum DistributionErrorReason {
    INVALID_TIME,
    INVALID_COLLECTION_IDS,
    INVALID_FANTIUM_FEE_BPS,
    INVALID_ADDRESS,
    INVALID_AMOUNT,
    ALREADY_CLOSED,
    PAYOUTS_STARTED
}

enum DistributionFundingErrorReason {
    CLOSED,
    INVALID_AMOUNT,
    FUNDING_ALREADY_DONE
}

enum DistributionCloseErrorReason {
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
    error ArrayLengthMismatch(uint256 lhs, uint256 rhs);

    event Claim(uint256 indexed _distributionId, uint256 indexed _tokenId, uint256 amount);
    event DistributionUpdate(uint256 indexed _distributionId, bytes32 indexed _field);
    event PayIn(uint256 indexed _distributionId, uint256 amount);
    event SnapShotTaken(uint256 indexed _distributionId);
    event PlatformUpdate(bytes32 indexed _update);

    // ========================================================================
    // Errors
    // ========================================================================
    error InvariantTransferFailed(address token, address from, address to, uint256 amount);
    error InvalidDistributionId(uint256 distributionId);
    error InvalidDistribution(DistributionErrorReason reason);
    error InvalidDistributionFunding(DistributionFundingErrorReason reason);
    error InvalidDistributionClose(DistributionCloseErrorReason reason);
    error InvalidClaim(ClaimErrorReason reason);
    error AthleteOnly(uint256 distributionId, address account, address expected);

    // ========================================================================
    // Distribution Event
    // ========================================================================
    function createDistribution(DistributionData memory data) external returns (uint256 distributionId);
    function updateDistribution(uint256 distributionId, DistributionData memory data) external;
    function fundDistribution(uint256 distributionId) external;
    function batchFundDistribution(uint256[] memory distributionIds) external;
    function closeDistribution(uint256 distributionId) external;
    function recomputeShares(uint256 distributionId) external;

    // ========================================================================
    // Claiming
    // ========================================================================
    function claim(uint256 tokenId, uint256 distributionId) external;
    function batchClaim(uint256[] memory tokenIds, uint256[] memory distributionIds) external;
}
