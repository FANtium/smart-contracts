// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Collection, IFANtiumAthletes } from "src/interfaces/IFANtiumAthletes.sol";
import {
    ClaimErrorReason,
    CollectionInfo,
    Distribution,
    DistributionCloseErrorReason,
    DistributionData,
    DistributionErrorReason,
    DistributionFundingErrorReason,
    IFANtiumClaiming
} from "src/interfaces/IFANtiumClaiming.sol";
import { TokenVersionUtil } from "src/utils/TokenVersionUtil.sol";

/**
 * @title FANtium Claiming contract V6.
 * @notice This contract is used to manage distributions and claim payouts for FAN token holders.
 * @dev Since V6, claiming no longer burns and re-mints the token with a bumped version: token ids are stable. The
 * claim record is `_distributionToBaseTokenToClaimed`, which has been the double-claim guard since V1.
 * @author Mathieu Bour - FANtium AG, based on previous work by MTX studio AG.
 *
 * @custom:oz-upgrades-from archive:FANtiumClaimingV5
 */
contract FANtiumClaimingV6 is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    IFANtiumClaiming
{
    using SafeERC20 for IERC20;

    // ========================================================================
    // Constants
    // ========================================================================
    uint256 private constant BPS_BASE = 10_000;
    /**
     * @dev Even in our greatest dreams, we will never pay out more than a billion!
     */
    uint256 private constant MAX_FUNDING_AMOUNT = 1_000_000_000;

    // Roles
    // ========================================================================
    /**
     * @notice Role of the ERC-2771 forwarders allowed to relay calls on behalf of users.
     */
    bytes32 public constant FORWARDER_ROLE = keccak256("FORWARDER_ROLE");

    // ========================================================================
    // State variables
    // ========================================================================
    /**
     * @notice ERC-20 token new distributions are paid out in.
     */
    address public globalPayoutToken;

    /**
     * @custom:oz-renamed-from trustedForwarder
     */
    address private UNUSED_trustedForwarder;

    /**
     * @notice FANtium NFT contract address.
     * @custom:oz-renamed-from fantiumNFTContract
     */
    IFANtiumAthletes public fantiumAthletes;

    /**
     * @dev Deprecated: kept for upgrade compatibility
     * @custom:oz-renamed-from userManager
     */
    address private UNUSED_userManager;

    /**
     * @dev mapping of distribution to Distribution
     * Distribution Event ID -> Distribution Event
     * @custom:oz-renamed-from distributionEvents
     * @custom:oz-retyped-from mapping(uint256 => FantiumClaimingV1.DistributionEvent)
     */
    mapping(uint256 => Distribution) private _distributions;

    /**
     * @notice mapping of distribution to baseTokenId to claimed
     * Distribution Event ID -> Base Token ID (token with version=0) -> Claimed
     * @custom:oz-renamed-from distributionEventToBaseTokenToClaimed
     */
    mapping(uint256 => mapping(uint256 => bool)) private _distributionToBaseTokenToClaimed;

    /**
     * @notice mapping of distribution to collectionId to CollectionInfo
     * Distribution Event ID -> Collection ID -> Collection Info
     * @custom:oz-renamed-from distributionEventToCollectionInfo
     */
    mapping(uint256 => mapping(uint256 => CollectionInfo)) private _distributionToCollectionInfo;

    /**
     * @notice mapping of distribution to payout token
     * Distribution Event ID -> Payout Token (IERC20)
     * @custom:oz-renamed-from distributionEventToPayoutToken
     */
    mapping(uint256 => IERC20) private _distributionToPayoutToken;

    /**
     * @notice ID the next created distribution receives; distribution IDs start at 1.
     * @custom:oz-renamed-from nextDistributionEventId
     */
    uint256 public nextDistributionId;

    /**
     * @notice The FANtium treasury address, receiving the unclaimed funds of closed distributions.
     */
    address public treasury;

    // ========================================================================
    // UUPS upgradeable pattern
    // ========================================================================
    /**
     * @notice Disables initializers on the implementation contract; the proxy is initialized instead.
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes a new proxy.
     * @param admin The address granted DEFAULT_ADMIN_ROLE
     */
    function initialize(address admin) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        nextDistributionId = 1;
    }

    /**
     * @notice Implementation of the upgrade authorization logic
     * @dev Restricted to the DEFAULT_ADMIN_ROLE. The new implementation address is unnamed: it is not checked.
     */
    // solhint-disable-next-line use-natspec
    function _authorizeUpgrade(address) internal view override {
        _checkRole(DEFAULT_ADMIN_ROLE);
    }

    // ========================================================================
    // Access control
    // ========================================================================
    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    // ========================================================================
    // Modifiers
    // ========================================================================
    /**
     * @dev Modifier to check if the sender is the athlete of the distribution or an admin.
     * @param distributionId The ID of the distribution
     */
    modifier onlyAthleteOrAdmin(uint256 distributionId) {
        if (_msgSender() != _distributions[distributionId].athleteAddress && !hasRole(DEFAULT_ADMIN_ROLE, _msgSender()))
        {
            revert AthleteOnly(distributionId, _msgSender(), _distributions[distributionId].athleteAddress);
        }
        _;
    }

    /**
     * @dev Modifier to check that the distribution exists.
     * @param distributionId The ID of the distribution
     */
    modifier onlyValidDistribution(uint256 distributionId) {
        if (!_distributions[distributionId].exists) {
            revert InvalidDistributionId(distributionId);
        }
        _;
    }

    // ========================================================================
    // Pause
    // ========================================================================
    /**
     * @notice Update contract pause status to `_paused`.
     */
    function pause() external onlyAdmin {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */
    function unpause() external onlyAdmin {
        _unpause();
    }

    // ========================================================================
    // ERC2771
    // ========================================================================
    /**
     * @notice Whether an address is a trusted ERC-2771 forwarder.
     * @param forwarder The address to check
     * @return Whether `forwarder` holds FORWARDER_ROLE
     */
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return hasRole(FORWARDER_ROLE, forwarder);
    }

    /**
     * @notice The caller, unwrapped from the calldata suffix when relayed by a trusted forwarder.
     * @return sender The original caller
     */
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

    /**
     * @notice The calldata, stripped of the sender suffix when relayed by a trusted forwarder.
     * @return The original calldata
     */
    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    // ========================================================================
    // Setters
    // ========================================================================
    /**
     * @notice Sets the FANtium Athletes NFT contract, whose `ownerOf` gates claims.
     * @dev Restricted to admin.
     * @param _fantiumAthletes The FANtium Athletes contract
     */
    function setFANtiumNFT(IFANtiumAthletes _fantiumAthletes) external onlyAdmin {
        fantiumAthletes = _fantiumAthletes;
    }

    /**
     * @notice Sets the payout token of distributions created from now on.
     * @dev Restricted to admin. Existing distributions keep the token they were created with.
     * @param _globalPayoutToken The ERC-20 payout token
     */
    function setGlobalPayoutToken(address _globalPayoutToken) external onlyAdmin {
        globalPayoutToken = _globalPayoutToken;
    }

    /**
     * @notice Sets the FANtium treasury address.
     * @dev Restricted to admin.
     * @param _treasury The new FANtium treasury address.
     */
    function setTreasury(address _treasury) external whenNotPaused onlyAdmin {
        treasury = _treasury;
    }

    // ========================================================================
    // Distribution
    // ========================================================================
    /**
     * @notice Get the distribution data.
     * @param distributionId The ID of the distribution
     * @return The distribution
     */
    function distributions(uint256 distributionId) public view returns (Distribution memory) {
        return _distributions[distributionId];
    }

    /**
     * @notice Get all the collection infos for a distribution.
     * @param distributionId The ID of the distribution
     * @return The collection infos, in the order of the distribution's `collectionIds`
     */
    function collectionInfos(uint256 distributionId) public view returns (CollectionInfo[] memory) {
        Distribution memory distribution = _distributions[distributionId];
        uint256 size = distribution.collectionIds.length;
        CollectionInfo[] memory output = new CollectionInfo[](size);

        for (uint256 i = 0; i < size; ++i) {
            output[i] = _distributionToCollectionInfo[distributionId][distribution.collectionIds[i]];
        }

        return output;
    }

    /**
     * @notice Check if the distribution data is valid.
     * @param data The distribution data
     */
    function _checkDistribution(DistributionData memory data) private view {
        // Check if the provided times are valid
        if (
            data.startTime == 0 || data.closeTime == 0 || data.startTime > data.closeTime
                || block.timestamp > data.closeTime
        ) {
            revert InvalidDistribution(DistributionErrorReason.INVALID_TIME);
        }

        // At least one collection is required
        if (data.collectionIds.length == 0) {
            revert InvalidDistribution(DistributionErrorReason.INVALID_COLLECTION_IDS);
        }

        // Ensure all collections exist
        for (uint256 i = 0; i < data.collectionIds.length; ++i) {
            if (!IFANtiumAthletes(fantiumAthletes).collections(data.collectionIds[i]).exists) {
                revert InvalidDistribution(DistributionErrorReason.INVALID_COLLECTION_IDS);
            }
        }

        if (data.fantiumFeeBPS >= BPS_BASE) {
            revert InvalidDistribution(DistributionErrorReason.INVALID_FANTIUM_FEE_BPS);
        }

        if (data.athleteAddress == address(0) || data.fantiumAddress == address(0)) {
            revert InvalidDistribution(DistributionErrorReason.INVALID_ADDRESS);
        }

        uint256 maxAmount = MAX_FUNDING_AMOUNT * 10 ** IERC20Metadata(globalPayoutToken).decimals();
        uint256 sum = data.totalTournamentEarnings + data.totalOtherEarnings;

        if (sum == 0 || sum >= maxAmount) {
            revert InvalidDistribution(DistributionErrorReason.INVALID_AMOUNT);
        }
    }

    /**
     * @notice Check if the distribution has started.
     * @param distributionId The ID of the distribution
     */
    function _checkDistributionNotStarted(uint256 distributionId) private view {
        if (_distributions[distributionId].claimedAmount > 0) {
            revert InvalidDistribution(DistributionErrorReason.PAYOUTS_STARTED);
        }
    }

    /**
     * @inheritdoc IFANtiumClaiming
     * @dev Restricted to admin. The payout token is `globalPayoutToken` at creation time.
     */
    function createDistribution(DistributionData calldata data) external onlyAdmin whenNotPaused returns (uint256) {
        _checkDistribution(data);

        uint256 distributionId = nextDistributionId;
        ++nextDistributionId;
        Distribution memory newDistribution = Distribution({
            distributionId: distributionId,
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
        _distributions[distributionId] = newDistribution;

        _distributionToPayoutToken[distributionId] = IERC20(globalPayoutToken);
        _computeShares(distributionId);
        return distributionId;
    }

    /**
     * @inheritdoc IFANtiumClaiming
     * @dev Restricted to admin. Reverts if the new total falls below the amount already paid in.
     */
    function updateDistribution(
        uint256 distributionId,
        DistributionData calldata data
    )
        external
        onlyAdmin
        onlyValidDistribution(distributionId)
    {
        _checkDistribution(data);

        Distribution memory existingDE = _distributions[distributionId];

        // Check if the distribution is closed
        if (existingDE.closed) {
            revert InvalidDistribution(DistributionErrorReason.ALREADY_CLOSED);
        }

        // earnings, fee, collectionIds may only be updated before the distribution has started
        if (
            data.totalTournamentEarnings != existingDE.totalTournamentEarnings
                || data.totalOtherEarnings != existingDE.totalOtherEarnings
                || !_sameCollectionIds(data.collectionIds, existingDE.collectionIds)
                || data.fantiumFeeBPS != existingDE.fantiumFeeBPS
        ) {
            // Earnings are updated - some extra checks are needed
            _checkDistributionNotStarted(distributionId);
        }

        existingDE.collectionIds = data.collectionIds;
        existingDE.athleteAddress = data.athleteAddress;
        existingDE.totalTournamentEarnings = data.totalTournamentEarnings;
        existingDE.totalOtherEarnings = data.totalOtherEarnings;
        existingDE.fantiumFeeAddress = data.fantiumAddress;
        existingDE.fantiumFeeBPS = data.fantiumFeeBPS;
        existingDE.startTime = data.startTime;
        existingDE.closeTime = data.closeTime;

        _distributions[distributionId] = existingDE;
        _computeShares(distributionId);

        Distribution memory updatedDE = _distributions[distributionId];
        if (updatedDE.tournamentDistributionAmount + updatedDE.otherDistributionAmount < updatedDE.amountPaidIn) {
            // Cannot lower the amount paid in
            revert InvalidDistribution(DistributionErrorReason.INVALID_AMOUNT);
        }
    }

    /**
     * @notice Whether two collection ID lists are identical, order included.
     * @param a The first list
     * @param b The second list
     * @return Whether `a` and `b` hold the same IDs in the same order
     */
    function _sameCollectionIds(uint256[] calldata a, uint256[] memory b) private pure returns (bool) {
        if (a.length != b.length) {
            return false;
        }
        for (uint256 i = 0; i < a.length; ++i) {
            if (a[i] != b[i]) {
                return false;
            }
        }
        return true;
    }

    /**
     * @notice Forcefully set the athlete address of a distribution.
     * Used only in extreme situations when the athletes don't have access to his wallet.
     * @param distributionId The ID of the distribution
     * @param newAthlete The new athlete address
     */
    function setDistributionAthlete(
        uint256 distributionId,
        address payable newAthlete
    )
        external
        onlyAdmin
        onlyValidDistribution(distributionId)
    {
        Distribution storage existingDE = _distributions[distributionId];

        if (newAthlete == address(0)) {
            revert InvalidDistribution(DistributionErrorReason.INVALID_ADDRESS);
        }

        existingDE.athleteAddress = newAthlete;
    }

    /**
     * @inheritdoc IFANtiumClaiming
     * @dev Restricted to the athlete of the distribution or an admin.
     */
    function fundDistribution(uint256 distributionId)
        public
        whenNotPaused
        onlyValidDistribution(distributionId)
        onlyAthleteOrAdmin(distributionId)
    {
        Distribution memory existingDE = _distributions[distributionId];

        // check that the distribution is open
        if (existingDE.closed) {
            revert InvalidDistributionFunding(DistributionFundingErrorReason.CLOSED);
        }

        uint256 totalAmount = existingDE.tournamentDistributionAmount + existingDE.otherDistributionAmount;
        uint256 missingAmount = totalAmount - existingDE.amountPaidIn;

        if (missingAmount == 0) {
            revert InvalidDistributionFunding(DistributionFundingErrorReason.FUNDING_ALREADY_DONE);
        }

        // Take the missing amount from the sender
        IERC20 token = _distributionToPayoutToken[distributionId];
        token.safeTransferFrom(_msgSender(), address(this), missingAmount);

        existingDE.amountPaidIn += missingAmount;
        _distributions[distributionId] = existingDE;
        emit PayIn(distributionId, missingAmount);
    }

    /**
     * @inheritdoc IFANtiumClaiming
     * @dev No modifier is needed here since `fundDistribution` checks the caller for each distribution.
     */
    function batchFundDistribution(uint256[] calldata distributionIds) external {
        for (uint256 i = 0; i < distributionIds.length; ++i) {
            fundDistribution(distributionIds[i]);
        }
    }

    /**
     * @inheritdoc IFANtiumClaiming
     * @dev Restricted to admin. Reverts while `treasury` is unset.
     */
    function closeDistribution(uint256 distributionId)
        external
        whenNotPaused
        onlyAdmin
        onlyValidDistribution(distributionId)
    {
        Distribution storage existingDE = _distributions[distributionId];
        if (existingDE.closed) {
            revert InvalidDistributionClose(DistributionCloseErrorReason.DISTRIBUTION_ALREADY_CLOSED);
        }

        if (treasury == address(0)) {
            revert InvalidDistributionClose(DistributionCloseErrorReason.TREASURY_NOT_SET);
        }

        existingDE.closed = true;
        uint256 closingAmount = existingDE.amountPaidIn - existingDE.claimedAmount;

        if (closingAmount == 0) {
            return;
        }

        IERC20 payOutToken = _distributionToPayoutToken[distributionId];
        payOutToken.safeTransfer(treasury, closingAmount);
    }

    // ========================================================================
    // Claiming
    // ========================================================================
    /**
     * @notice Number of distributions the token has claimed.
     * @dev Claims are recorded per base token id, so the count is the same for every version of a token id. Up to
     * V5, each claim also burned the token and re-minted it with the next version: the version of a token id minted
     * before V6 therefore equals its claim count at that time, and stays frozen since.
     * @param tokenId The ID of the token, any version
     * @return count The number of distributions the token has claimed
     */
    function claimCount(uint256 tokenId) external view returns (uint256 count) {
        (,,, uint256 baseTokenId) = TokenVersionUtil.getTokenInfo(tokenId);
        for (uint256 distributionId = 1; distributionId < nextDistributionId; ++distributionId) {
            if (_distributionToBaseTokenToClaimed[distributionId][baseTokenId]) {
                ++count;
            }
        }
    }

    /**
     * @notice To be eligible for a claim, a token:
     * - must be part of one of the collections included in the distribution
     * - its number must be in the snapshot, i.e. it must have been minted before the distribution started
     * - must not have been claimed yet for that distribution
     * @param distributionId The ID of the distribution
     * @param tokenId The ID of the token, any version
     * @return Whether the token can claim the distribution
     */
    function isEligibleForClaim(uint256 distributionId, uint256 tokenId) public view returns (bool) {
        Distribution memory existingDE = _distributions[distributionId];
        (uint256 collectionId,, uint256 number, uint256 baseTokenId) = TokenVersionUtil.getTokenInfo(tokenId);

        // Check if the token is from a valid collection
        bool collectionOK;
        for (uint256 i = 0; i < existingDE.collectionIds.length; ++i) {
            if (existingDE.collectionIds[i] == collectionId) {
                collectionOK = true;
                break;
            }
        }

        if (!collectionOK) {
            return false;
        }

        // Now, check if the token was minted before the distribution started
        if (number >= _distributionToCollectionInfo[distributionId][collectionId].mintedTokens) {
            return false;
        }

        // Finally, check if the token has already been claimed for this distribution
        return !_distributionToBaseTokenToClaimed[distributionId][baseTokenId];
    }

    /**
     * @inheritdoc IFANtiumClaiming
     * @dev The token keeps its id: since V6, claiming no longer burns and re-mints it.
     */
    function claim(uint256 tokenId, uint256 distributionId) public whenNotPaused onlyValidDistribution(distributionId) {
        Distribution memory existingDE = _distributions[distributionId];
        if (existingDE.closed) {
            revert InvalidDistributionClose(DistributionCloseErrorReason.DISTRIBUTION_ALREADY_CLOSED);
        }

        if (existingDE.amountPaidIn < existingDE.tournamentDistributionAmount + existingDE.otherDistributionAmount) {
            revert InvalidClaim(ClaimErrorReason.NOT_FULLY_PAID_IN);
        }

        if (_msgSender() != fantiumAthletes.ownerOf(tokenId)) {
            revert InvalidClaim(ClaimErrorReason.ONLY_TOKEN_OWNER);
        }

        if (existingDE.startTime >= block.timestamp || existingDE.closeTime <= block.timestamp) {
            revert InvalidClaim(ClaimErrorReason.INVALID_TIME_FRAME);
        }

        if (!isEligibleForClaim(distributionId, tokenId)) {
            revert InvalidClaim(ClaimErrorReason.NOT_ELIGIBLE);
        }

        // Mark the token as claimed
        (uint256 collectionId,,, uint256 baseTokenId) = TokenVersionUtil.getTokenInfo(tokenId);
        _distributionToBaseTokenToClaimed[distributionId][baseTokenId] = true;

        // Compute the claim amount
        CollectionInfo memory collectionInfo = _distributionToCollectionInfo[distributionId][collectionId];
        uint256 claimAmount = collectionInfo.tokenTournamentClaim + collectionInfo.tokenOtherClaim;

        if (existingDE.claimedAmount + claimAmount > existingDE.amountPaidIn) {
            revert InvalidClaim(ClaimErrorReason.INVARIANT_EXCEED_PAID_IN);
        }
        _distributions[distributionId].claimedAmount += claimAmount;

        // Split the claim amount between FANtium and the user
        uint256 fantiumRevenue_ = ((claimAmount * existingDE.fantiumFeeBPS) / BPS_BASE);
        uint256 userRevenue_ = claimAmount - fantiumRevenue_;

        // set addresses from storage
        address fantiumAddress_ = existingDE.fantiumFeeAddress;
        IERC20 payOutToken = _distributionToPayoutToken[distributionId];

        if (fantiumRevenue_ > 0) {
            payOutToken.safeTransfer(fantiumAddress_, fantiumRevenue_);
        }
        if (userRevenue_ > 0) {
            payOutToken.safeTransfer(_msgSender(), userRevenue_);
        }

        emit Claim(distributionId, tokenId, claimAmount);
    }

    /**
     * @inheritdoc IFANtiumClaiming
     */
    function batchClaim(uint256[] calldata tokenIds, uint256[] calldata distributionIds) external whenNotPaused {
        if (tokenIds.length != distributionIds.length) {
            revert ArrayLengthMismatch(tokenIds.length, distributionIds.length);
        }

        for (uint256 i = 0; i < tokenIds.length; ++i) {
            claim(tokenIds[i], distributionIds[i]);
        }
    }

    /**
     * @notice Snapshots a distribution's collections and recomputes the amount it pays out.
     * @dev Recompute the amount to distribute to the holders for a distribution based on the distribution
     * tournament and other earnings. Also saves a snapshot of the number of minted tokens for each collection to
     * prevent users to mint tokens after the distribution has started.
     * @param distributionId The ID of the distribution
     */
    function _computeShares(uint256 distributionId) internal {
        Distribution memory distribution = _distributions[distributionId];

        // Sum of all the holders' tournament and other earnings shares in 1e7
        uint256 holdersTournamentEarningsShare1e7;
        uint256 holdersOtherEarningsShare1e7;

        for (uint256 i = 0; i < distribution.collectionIds.length; ++i) {
            uint256 collectionId = distribution.collectionIds[i];
            Collection memory collection = fantiumAthletes.collections(collectionId);

            // Compute the token's share of tournament and other earnings
            uint256 tournamentClaim =
                ((distribution.totalTournamentEarnings * collection.tournamentEarningShare1e7) / 1e7);
            uint256 otherClaim = ((distribution.totalOtherEarnings * collection.otherEarningShare1e7) / 1e7);

            _distributionToCollectionInfo[distributionId][collectionId] = CollectionInfo({
                // record the current number of minted tokens so that tokens bought afterwards are not eligible for
                // the distribution
                mintedTokens: collection.invocations,
                tokenTournamentClaim: tournamentClaim,
                tokenOtherClaim: otherClaim
            });

            // Increment the sum of all the holders' tournament and other earnings shares in 1e7
            holdersTournamentEarningsShare1e7 += (collection.invocations * collection.tournamentEarningShare1e7);
            holdersOtherEarningsShare1e7 += (collection.invocations * collection.otherEarningShare1e7);
        }

        // Calculate the tournament and other distribution amounts
        distribution.tournamentDistributionAmount =
            (holdersTournamentEarningsShare1e7 * distribution.totalTournamentEarnings) / 1e7;
        distribution.otherDistributionAmount = (holdersOtherEarningsShare1e7 * distribution.totalOtherEarnings) / 1e7;

        _distributions[distributionId] = distribution;
        emit SnapShotTaken(distributionId);
    }

    /**
     * @inheritdoc IFANtiumClaiming
     * @dev Restricted to admin. Runs `_computeShares`.
     */
    function recomputeShares(uint256 distributionId)
        external
        whenNotPaused
        onlyAdmin
        onlyValidDistribution(distributionId)
    {
        return _computeShares(distributionId);
    }
}
