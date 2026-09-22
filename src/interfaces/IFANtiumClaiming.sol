// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/**
 * @dev CAUTION: This struct is used to store the distribution information.
 * Since it is used in the upgradeable contract, do not change the order of the fields.
 */
struct Distribution {
    /**
     * @notice The distribution ID.
     * @custom:oz-renamed-from distributionEventId
     */
    uint256 distributionId;
    /**
     * @notice NFT collections whose holders can claim.
     */
    uint256[] collectionIds;
    /**
     * @notice Athlete address, allowed to fund the distribution (alongside the admin).
     */
    address payable athleteAddress;
    /**
     * @notice Holders' slice of the tournament earnings, in payout token decimals.
     */
    uint256 totalTournamentEarnings;
    /**
     * @notice Holders' slice of the other earnings, in payout token decimals.
     */
    uint256 totalOtherEarnings;
    /**
     * @notice Total tournament amount paid out to the snapshotted holders, in payout token decimals.
     */
    uint256 tournamentDistributionAmount;
    /**
     * @notice Total other amount paid out to the snapshotted holders, in payout token decimals.
     */
    uint256 otherDistributionAmount;
    /**
     * @notice Amount funded so far.
     */
    uint256 amountPaidIn;
    /**
     * @notice Amount claimed so far, FANtium fee included.
     */
    uint256 claimedAmount;
    /**
     * @notice FANtium fee taken out of each claim, in basis points.
     */
    uint256 fantiumFeeBPS;
    /**
     * @notice Address receiving the FANtium fee of each claim.
     */
    address payable fantiumFeeAddress;
    /**
     * @notice Start of the claim window (exclusive), as a Unix timestamp.
     */
    uint256 startTime;
    /**
     * @notice End of the claim window (exclusive), as a Unix timestamp.
     */
    uint256 closeTime;
    /**
     * @notice Whether the distribution exists.
     */
    bool exists;
    /**
     * @notice Whether the distribution is closed; its unclaimed remainder has then been sent to the treasury.
     */
    bool closed;
}

/**
 * @notice Input of `createDistribution` and `updateDistribution`; see `Distribution` for the meaning of each field.
 */
struct DistributionData {
    address payable athleteAddress;
    uint256 totalTournamentEarnings;
    uint256 totalOtherEarnings;
    uint256 startTime;
    uint256 closeTime;
    uint256[] collectionIds;
    /**
     * @notice Stored as `Distribution.fantiumFeeAddress`.
     */
    address payable fantiumAddress;
    uint256 fantiumFeeBPS;
}

/**
 * @dev CAUTION: This struct is used to store the collection information.
 * Since it is used in the upgradeable contract, do not change the order of the fields.
 */
struct CollectionInfo {
    /**
     * @notice Tokens minted when the snapshot was taken: only token numbers below it can claim.
     */
    uint256 mintedTokens;
    /**
     * @notice Tournament amount each token claims, FANtium fee included.
     */
    uint256 tokenTournamentClaim;
    /**
     * @notice Other amount each token claims, FANtium fee included.
     */
    uint256 tokenOtherClaim;
}

/**
 * @notice Reason of an `InvalidDistribution` error.
 */
enum DistributionErrorReason {
    INVALID_TIME,
    INVALID_COLLECTION_IDS,
    INVALID_FANTIUM_FEE_BPS,
    INVALID_ADDRESS,
    INVALID_AMOUNT,
    ALREADY_CLOSED,
    PAYOUTS_STARTED
}

/**
 * @notice Reason of an `InvalidDistributionFunding` error.
 */
enum DistributionFundingErrorReason {
    CLOSED,
    INVALID_AMOUNT,
    FUNDING_ALREADY_DONE
}

/**
 * @notice Reason of an `InvalidDistributionClose` error.
 */
enum DistributionCloseErrorReason {
    DISTRIBUTION_ALREADY_CLOSED,
    TREASURY_NOT_SET
}

/**
 * @notice Reason of an `InvalidClaim` error. Unused values are kept: removing them would renumber the others.
 */
enum ClaimErrorReason {
    INVALID_AMOUNT,
    NOT_FULLY_PAID_IN,
    ONLY_TOKEN_OWNER,
    NOT_IDENTED,
    INVALID_TIME_FRAME,
    NOT_ELIGIBLE,
    INVARIANT_EXCEED_PAID_IN
}

/**
 * @title FANtium Claiming interface.
 * @notice Distributions of athlete earnings to FAN token holders: FANtium creates a distribution, the athlete (or the
 * admin) funds it, holders claim their share during the claim window, and the unclaimed remainder goes to the
 * treasury when the distribution is closed.
 * @author Mathieu Bour - FANtium AG, based on previous work by MTX studio AG.
 */
interface IFANtiumClaiming {
    // ========================================================================
    // Events
    // ========================================================================
    /**
     * @notice Emitted when a token claims its share of a distribution.
     * @param _distributionId The ID of the distribution
     * @param _tokenId The ID of the token that claimed
     * @param amount The amount claimed, FANtium fee included
     */
    event Claim(uint256 indexed _distributionId, uint256 indexed _tokenId, uint256 amount);

    /**
     * @notice Emitted when a distribution is funded.
     * @param _distributionId The ID of the distribution
     * @param amount The amount paid in
     */
    event PayIn(uint256 indexed _distributionId, uint256 amount);

    /**
     * @notice Emitted when the collections of a distribution are snapshotted and its amounts recomputed.
     * @param _distributionId The ID of the distribution
     */
    event SnapShotTaken(uint256 indexed _distributionId);

    // ========================================================================
    // Errors
    // ========================================================================
    /**
     * @notice Two arrays that must have the same length do not.
     * @param lhs The length of the first array
     * @param rhs The length of the second array
     */
    error ArrayLengthMismatch(uint256 lhs, uint256 rhs);

    /**
     * @notice The distribution does not exist.
     * @param distributionId The ID of the distribution
     */
    error InvalidDistributionId(uint256 distributionId);

    /**
     * @notice The distribution data, or the requested change to it, is invalid.
     * @param reason Why the distribution is invalid
     */
    error InvalidDistribution(DistributionErrorReason reason);

    /**
     * @notice The distribution cannot be funded.
     * @param reason Why the funding failed
     */
    error InvalidDistributionFunding(DistributionFundingErrorReason reason);

    /**
     * @notice The distribution cannot be closed.
     * @param reason Why the close failed
     */
    error InvalidDistributionClose(DistributionCloseErrorReason reason);

    /**
     * @notice The claim is invalid.
     * @param reason Why the claim failed
     */
    error InvalidClaim(ClaimErrorReason reason);

    /**
     * @notice The caller is neither the athlete of the distribution nor an admin.
     * @param distributionId The ID of the distribution
     * @param account The caller
     * @param expected The athlete address of the distribution
     */
    error AthleteOnly(uint256 distributionId, address account, address expected);

    // ========================================================================
    // Distribution Event
    // ========================================================================
    /**
     * @notice Create a new distribution and snapshot its collections.
     * @param data The distribution data
     * @return distributionId The ID of the new distribution
     */
    function createDistribution(DistributionData calldata data) external returns (uint256 distributionId);

    /**
     * @notice Update a distribution. Earnings, fee and collections can only change until the first claim.
     * @param distributionId The ID of the distribution
     * @param data The distribution data
     */
    function updateDistribution(uint256 distributionId, DistributionData calldata data) external;

    /**
     * @notice Pay in the missing amount of a distribution, taken from the caller.
     * @param distributionId The ID of the distribution
     */
    function fundDistribution(uint256 distributionId) external;

    /**
     * @notice Pay in the missing amount of several distributions, taken from the caller.
     * @param distributionIds The IDs of the distributions
     */
    function batchFundDistribution(uint256[] calldata distributionIds) external;

    /**
     * @notice Close a distribution, sending its unclaimed remainder to the treasury.
     * @param distributionId The ID of the distribution
     */
    function closeDistribution(uint256 distributionId) external;

    /**
     * @notice Snapshot the collections of a distribution again and recompute the amount it pays out.
     * @param distributionId The ID of the distribution
     */
    function recomputeShares(uint256 distributionId) external;

    // ========================================================================
    // Claiming
    // ========================================================================
    /**
     * @notice Claim the share of a distribution owed to a token, paid to its owner.
     * @param tokenId The ID of the token
     * @param distributionId The ID of the distribution
     */
    function claim(uint256 tokenId, uint256 distributionId) external;

    /**
     * @notice Claim several (token, distribution) pairs; `tokenIds[i]` claims `distributionIds[i]`.
     * @param tokenIds The IDs of the tokens
     * @param distributionIds The IDs of the distributions
     */
    function batchClaim(uint256[] calldata tokenIds, uint256[] calldata distributionIds) external;
}
