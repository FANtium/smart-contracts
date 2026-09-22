// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";
import { FANtiumClaimingV6 } from "src/FANtiumClaimingV6.sol";
import { IFANtiumAthletes } from "src/interfaces/IFANtiumAthletes.sol";
import { CollectionInfo, Distribution } from "src/interfaces/IFANtiumClaiming.sol";

/**
 * @notice Rehearses the V5 -> V6 mainnet upgrade of FANtiumClaim against forked Polygon state: executes
 *         `upgradeToAndCall(setTreasury)` as the FANtium Safe, checks that every distribution survives the
 *         upgrade byte for byte, closes every expired distribution and checks that exactly its unclaimed
 *         remainder reaches the treasury, then has a real holder claim an open distribution and checks that the
 *         token keeps its id. Skipped when ALCHEMY_API_KEY is not set (e.g. public CI).
 */
contract UpgradeMainnetClaimingV6ForkTest is Test {
    address public constant FANTIUM_CLAIM_PROXY = 0x534db6CE612486F179ef821a57ee93F44718a002;
    /**
     * @notice FANtium Safe, holder of DEFAULT_ADMIN_ROLE on the proxy.
     */
    address public constant FANTIUM_SAFE = 0x417834e4371610BB81DC150fF47C0859b72318B0;

    /**
     * @notice EIP-1967 implementation slot, used to detect whether the upgrade already happened.
     */
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    /**
     * @notice The V5 implementation the rehearsal upgrades from.
     */
    address private constant _V5_IMPLEMENTATION = 0x82254aA06C29F4b136D0fdd72A4b5bB09140aD5b;
    /**
     * @notice Storage slot of `_distributionToPayoutToken`, which V5 does not expose through a getter.
     */
    uint256 private constant _PAYOUT_TOKEN_MAPPING_SLOT = 308;

    address private treasury = makeAddr("treasury");

    function test_fork_upgradeMainnetClaimingV6_closesExpiredDistributionsToTreasury() public {
        vm.skip(bytes(vm.envOr("ALCHEMY_API_KEY", string(""))).length == 0);
        vm.createSelectFork(vm.rpcUrl("polygon"));

        // The rehearsal only applies while mainnet still runs V5.
        address currentImplementation = address(uint160(uint256(vm.load(FANTIUM_CLAIM_PROXY, _IMPLEMENTATION_SLOT))));
        vm.skip(currentImplementation != _V5_IMPLEMENTATION);

        FANtiumClaimingV6 claiming = FANtiumClaimingV6(FANTIUM_CLAIM_PROXY);
        uint256 nextDistributionId = claiming.nextDistributionId();
        assertGt(nextDistributionId, 1, "no distributions on mainnet?");

        // Snapshot the pre-upgrade state.
        bytes[] memory pre = new bytes[](nextDistributionId);
        for (uint256 id = 1; id < nextDistributionId; id++) {
            pre[id] = abi.encode(claiming.distributions(id), claiming.collectionInfos(id));
        }
        address fantiumAthletes = address(claiming.fantiumAthletes());
        address globalPayoutToken = claiming.globalPayoutToken();

        // Upgrade and set the treasury atomically, exactly as the Safe will.
        FANtiumClaimingV6 implementation = new FANtiumClaimingV6();
        vm.prank(FANTIUM_SAFE);
        UUPSUpgradeable(FANTIUM_CLAIM_PROXY)
            .upgradeToAndCall(address(implementation), abi.encodeCall(FANtiumClaimingV6.setTreasury, (treasury)));

        // Storage is untouched, the treasury is set.
        assertEq(claiming.treasury(), treasury, "treasury not set");
        assertEq(claiming.nextDistributionId(), nextDistributionId, "nextDistributionId changed");
        assertEq(address(claiming.fantiumAthletes()), fantiumAthletes, "fantiumAthletes changed");
        assertEq(claiming.globalPayoutToken(), globalPayoutToken, "globalPayoutToken changed");
        for (uint256 id = 1; id < nextDistributionId; id++) {
            assertEq(
                keccak256(abi.encode(claiming.distributions(id), claiming.collectionInfos(id))),
                keccak256(pre[id]),
                "distribution changed"
            );
        }

        // Close every expired distribution: each sends exactly its unclaimed remainder to the treasury.
        uint256 closed;
        for (uint256 id = 1; id < nextDistributionId; id++) {
            Distribution memory distribution = claiming.distributions(id);
            if (distribution.closed || distribution.closeTime > block.timestamp) {
                continue;
            }

            IERC20 payoutToken = _payoutToken(id);
            uint256 remainder = distribution.amountPaidIn - distribution.claimedAmount;
            uint256 treasuryBefore = payoutToken.balanceOf(treasury);
            uint256 athleteBefore = payoutToken.balanceOf(distribution.athleteAddress);

            vm.prank(FANTIUM_SAFE);
            claiming.closeDistribution(id);

            assertTrue(claiming.distributions(id).closed, "distribution not closed");
            assertEq(payoutToken.balanceOf(treasury) - treasuryBefore, remainder, "treasury did not get the remainder");
            assertEq(payoutToken.balanceOf(distribution.athleteAddress), athleteBefore, "athlete balance changed");
            closed++;
        }
        assertGt(closed, 0, "no expired distribution to close");
        emit log_named_uint("expired distributions closed", closed);
        emit log_named_uint("treasury USDC.e", _payoutToken(1).balanceOf(treasury));
        emit log_named_uint("treasury USDC", IERC20(globalPayoutToken).balanceOf(treasury));

        // A real holder claims an open distribution: paid, and the token keeps its id and owner.
        (uint256 distributionId, uint256 tokenId, address owner) = _findEligibleClaim(claiming, nextDistributionId);
        uint256 version = (tokenId % 1_000_000) / 10_000;
        assertEq(claiming.claimCount(tokenId), version, "pre-V6 version equals the recorded claim count");

        IERC20 token = _payoutToken(distributionId);
        uint256 balanceBefore = token.balanceOf(owner);
        vm.prank(owner);
        claiming.claim(tokenId, distributionId);

        assertEq(claiming.fantiumAthletes().ownerOf(tokenId), owner, "token id changed on claim");
        assertEq(claiming.claimCount(tokenId), version + 1, "claim not recorded");
        assertGt(token.balanceOf(owner), balanceBefore, "holder not paid");
        emit log_named_uint("claimed with stable token id", tokenId);
    }

    /**
     * @dev Finds the first live token that can claim an open, funded distribution. Token ids carry the pre-V6
     * version, so every version of each snapshotted token number is probed with `ownerOf`.
     */
    function _findEligibleClaim(
        FANtiumClaimingV6 claiming,
        uint256 nextDistributionId
    )
        private
        view
        returns (uint256 distributionId, uint256 tokenId, address owner)
    {
        IFANtiumAthletes athletes = claiming.fantiumAthletes();
        for (distributionId = nextDistributionId - 1; distributionId > 0; distributionId--) {
            Distribution memory distribution = claiming.distributions(distributionId);
            if (
                distribution.closed || distribution.closeTime <= block.timestamp
                    || distribution.startTime >= block.timestamp
            ) {
                continue;
            }

            CollectionInfo[] memory infos = claiming.collectionInfos(distributionId);
            for (uint256 i = 0; i < infos.length; i++) {
                uint256 collectionId = distribution.collectionIds[i];
                for (uint256 number = 0; number < infos[i].mintedTokens; number++) {
                    for (uint256 v = 0; v <= 4; v++) {
                        tokenId = collectionId * 1_000_000 + v * 10_000 + number;
                        try athletes.ownerOf(tokenId) returns (address tokenOwner) {
                            if (claiming.isEligibleForClaim(distributionId, tokenId)) {
                                return (distributionId, tokenId, tokenOwner);
                            }
                            break;
                        } catch { }
                    }
                }
            }
        }
        revert("no eligible claim on an open distribution");
    }

    function _payoutToken(uint256 distributionId) private view returns (IERC20) {
        bytes32 slot = keccak256(abi.encode(distributionId, _PAYOUT_TOKEN_MAPPING_SLOT));
        return IERC20(address(uint160(uint256(vm.load(FANTIUM_CLAIM_PROXY, slot)))));
    }
}
