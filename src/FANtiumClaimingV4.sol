// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { StringsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
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
import { IFANtiumUserManager } from "src/interfaces/IFANtiumUserManager.sol";
import { TokenVersionUtil } from "src/utils/TokenVersionUtil.sol";

/**
 * @title FANtium Claining contract V4.
 * @notice This contract is used to manage distributions and claim payouts for FAN token holders.
 * @author Mathieu Bour - FANtium AG, based on previous work by MTX studio AG.
 *
 * @custom:oz-upgrades-from src/archive/FANtiumClaimingV3.sol:FANtiumClaimingV3
 */
contract FANtiumClaimingV4 is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    IFANtiumClaiming
{
    using StringsUpgradeable for uint256;
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
    bytes32 public constant FORWARDER_ROLE = keccak256("FORWARDER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // ========================================================================
    // State variables
    // ========================================================================
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
     * @notice User manager contract address
     * @custom:oz-renamed-from fantiumUserManager
     */
    IFANtiumUserManager public userManager;

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
     * @custom:oz-renamed-from nextDistributionEventId
     */
    uint256 public nextDistributionId;

    // ========================================================================
    // UUPS upgradeable pattern
    // ========================================================================
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        nextDistributionId = 1;
    }

    /**
     * @notice Implementation of the upgrade authorization logic
     * @dev Restricted to the DEFAULT_ADMIN_ROLE
     */
    function _authorizeUpgrade(address) internal view override {
        _checkRole(DEFAULT_ADMIN_ROLE);
    }

    // ========================================================================
    // Access control
    // ========================================================================
    modifier onlyRoleOrAdmin(bytes32 role) {
        _checkRoleOrAdmin(role);
        _;
    }

    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    modifier onlyManagerOrAdmin() {
        _checkRoleOrAdmin(MANAGER_ROLE);
        _;
    }

    function _checkRoleOrAdmin(bytes32 role) internal view virtual {
        if (!hasRole(role, _msgSender()) && !hasRole(DEFAULT_ADMIN_ROLE, _msgSender())) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(_msgSender()),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    // ========================================================================
    // Modifiers
    // ========================================================================
    modifier onlyAthlete(uint256 distributionId) {
        if (_msgSender() != _distributions[distributionId].athleteAddress) {
            revert AthleteOnly(distributionId, _msgSender(), _distributions[distributionId].athleteAddress);
        }
        _;
    }

    /**
     * @dev Modifier to check if the sender is the athlete, a manager or an admin.
     * @param distributionId The ID of the distribution
     */
    modifier onlyAthleteOrManagerOrAdmin(uint256 distributionId) {
        if (
            _msgSender() != _distributions[distributionId].athleteAddress && !hasRole(MANAGER_ROLE, _msgSender())
                && !hasRole(DEFAULT_ADMIN_ROLE, _msgSender())
        ) {
            revert AthleteOnly(distributionId, _msgSender(), _distributions[distributionId].athleteAddress);
        }
        _;
    }

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
    function pause() external onlyManagerOrAdmin {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */
    function unpause() external onlyManagerOrAdmin {
        _unpause();
    }

    // ========================================================================
    // ERC2771
    // ========================================================================
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return hasRole(FORWARDER_ROLE, forwarder);
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

    // ========================================================================
    // Setters
    // ========================================================================
    function setFANtiumNFT(IFANtiumAthletes _fantiumAthletes) external onlyManagerOrAdmin {
        fantiumAthletes = _fantiumAthletes;
    }

    function setUserManager(IFANtiumUserManager _userManager) external onlyManagerOrAdmin {
        userManager = _userManager;
    }

    function setGlobalPayoutToken(address _globalPayoutToken) external onlyManagerOrAdmin {
        globalPayoutToken = _globalPayoutToken;
    }

    // ========================================================================
    // Distribution
    // ========================================================================
    /**
     * @notice Get the distribution data.
     * @param distributionId The ID of the distribution
     */
    function distributions(uint256 distributionId) public view returns (Distribution memory) {
        return _distributions[distributionId];
    }

    /**
     * @notice Get all the collection infos for a distribution.
     * @param distributionId The ID of the distribution
     */
    function collectionInfos(uint256 distributionId) public view returns (CollectionInfo[] memory) {
        Distribution memory distribution = _distributions[distributionId];
        uint256 size = distribution.collectionIds.length;
        CollectionInfo[] memory output = new CollectionInfo[](size);

        for (uint256 i = 0; i < size; i++) {
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
        for (uint256 i = 0; i < data.collectionIds.length; i++) {
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
     * @notice Create a new distribution.
     * @param data The distribution data
     */
    function createDistribution(DistributionData memory data)
        external
        onlyManagerOrAdmin
        whenNotPaused
        returns (uint256)
    {
        _checkDistribution(data);

        uint256 distributionId = nextDistributionId++;
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
     * @notice Update a distribution.
     * @dev Only the manager can update a distribution.
     * @param distributionId The ID of the distribution
     * @param data The distribution data
     */
    function updateDistribution(
        uint256 distributionId,
        DistributionData memory data
    )
        external
        onlyManagerOrAdmin
        onlyValidDistribution(distributionId)
    {
        _checkDistribution(data);

        Distribution memory existingDE = _distributions[distributionId];

        // Check if the distribution is closed
        if (existingDE.closed) {
            revert InvalidDistribution(DistributionErrorReason.ALREADY_CLOSED);
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

        // earnings, fee, collectionIds may only be updated before the distribution has started
        if (
            data.totalTournamentEarnings != existingDE.totalTournamentEarnings
                || data.totalOtherEarnings != existingDE.totalOtherEarnings || collectionIdsChanged
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
     * Forcefully set the athlete address of a distribution.
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
     * @notice Pay the distribution amount for a distribution.
     * @param distributionId The ID of the distribution
     */
    function fundDistribution(uint256 distributionId)
        public
        whenNotPaused
        onlyValidDistribution(distributionId)
        onlyAthlete(distributionId)
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
     * @notice Batch fund distributions.
     * @dev No modifier is needed here since the caller is already checked for being the athlete.
     * @param distributionIds The IDs of the distributions
     */
    function batchFundDistribution(uint256[] memory distributionIds) external {
        for (uint256 i = 0; i < distributionIds.length; i++) {
            fundDistribution(distributionIds[i]);
        }
    }

    /**
     * @notice Close a distribution, sending the remaining funds to the athlete.
     * @param distributionId The ID of the distribution
     */
    function closeDistribution(uint256 distributionId)
        external
        whenNotPaused
        onlyManagerOrAdmin
        onlyValidDistribution(distributionId)
    {
        Distribution storage existingDE = _distributions[distributionId];
        if (existingDE.closed) {
            revert InvalidDistributionClose(DistributionCloseErrorReason.DISTRIBUTION_ALREADY_CLOSED);
        }

        if (existingDE.athleteAddress == address(0)) {
            revert InvalidDistributionClose(DistributionCloseErrorReason.ATHLETE_ADDRESS_NOT_SET);
        }

        existingDE.closed = true;
        uint256 closingAmount = existingDE.amountPaidIn - existingDE.claimedAmount;

        if (closingAmount == 0) {
            return;
        }

        IERC20 payOutToken = _distributionToPayoutToken[distributionId];
        payOutToken.safeTransfer(existingDE.athleteAddress, closingAmount);
    }

    // ========================================================================
    // Claiming
    // ========================================================================
    /**
     * @notice To be eligiblem for a claim, a token:
     * - must be part of one of the collections included in the distribution
     * - is number must be in the snapshot, e.g. it must have been minted before the distribution started
     * - must not have been claimed yet for that distribution
     */
    function isEligibleForClaim(uint256 distributionId, uint256 tokenId) public view returns (bool) {
        Distribution memory existingDE = _distributions[distributionId];
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

        // Now, check if the token was minted before the distribution started
        if (number >= _distributionToCollectionInfo[distributionId][collectionId].mintedTokens) {
            return false;
        }

        // Finally, check if the token has already been claimed for this distribution
        return !_distributionToBaseTokenToClaimed[distributionId][baseTokenId];
    }

    /**
     * @notice Claim rewards associated with a token of a specific distribution.
     * @param tokenId The ID of the token
     * @param distributionId The ID of the distribution
     */
    function claim(
        uint256 tokenId,
        uint256 distributionId
    )
        public
        whenNotPaused
        onlyValidDistribution(distributionId)
    {
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

        if (!userManager.isIDENT(_msgSender())) {
            revert InvalidClaim(ClaimErrorReason.NOT_IDENTED);
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

        // Upgrade the token version
        fantiumAthletes.upgradeTokenVersion(tokenId);

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
     * @notice Batch claim for multiple tokens.
     * @param tokenIds The IDs of the tokens
     * @param distributionIds The IDs of the distributions
     */
    function batchClaim(uint256[] memory tokenIds, uint256[] memory distributionIds) external whenNotPaused {
        if (tokenIds.length != distributionIds.length) {
            revert ArrayLengthMismatch(tokenIds.length, distributionIds.length);
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            claim(tokenIds[i], distributionIds[i]);
        }
    }

    /**
     * @dev Given a distribution ID, a token's share of tournament earnings and a token's share of other earnings,
     * this function calculates the amount to send to the user.
     * @param distributionId The ID of the distribution
     * @param tournamentEarningsShare1e7 The share of tournament earnings in 1e7
     * @param otherEarningShare1e7 The share of other earnings in 1e7
     * @return tournamentClaim The amount to send to the user for tournament earnings
     * @return otherClaim The amount to send to the user for other earnings
     */
    function computeShares(
        uint256 distributionId,
        uint256 tournamentEarningsShare1e7,
        uint256 otherEarningShare1e7
    )
        internal
        view
        returns (uint256 tournamentClaim, uint256 otherClaim)
    {
        Distribution memory distribution = _distributions[distributionId];
        tournamentClaim = ((distribution.totalTournamentEarnings * tournamentEarningsShare1e7) / 1e7);
        otherClaim = ((distribution.totalOtherEarnings * otherEarningShare1e7) / 1e7);
    }

    /**
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

        for (uint256 i = 0; i < distribution.collectionIds.length; i++) {
            uint256 collectionId = distribution.collectionIds[i];
            Collection memory collection = fantiumAthletes.collections(collectionId);

            // Compute the token's share of tournament and other earnings
            uint256 tournamentClaim =
                ((distribution.totalTournamentEarnings * collection.tournamentEarningShare1e7) / 1e7);
            uint256 otherClaim = ((distribution.totalOtherEarnings * collection.otherEarningShare1e7) / 1e7);

            _distributionToCollectionInfo[distributionId][collectionId] = CollectionInfo({
                // we record the current number of minted token to avoid user to purchase tokens afterwrads an be
                // eligible for the distribution
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
     * @notice Call the _computeShares function manually.
     * @dev Only managers or admins can call this function.
     * @param distributionId The ID of the distribution
     */
    function recomputeShares(uint256 distributionId)
        external
        whenNotPaused
        onlyManagerOrAdmin
        onlyValidDistribution(distributionId)
    {
        return _computeShares(distributionId);
    }
}
