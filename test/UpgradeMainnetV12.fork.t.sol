// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Test } from "forge-std/Test.sol";
import { PhaseSeedsFixture } from "script/utils/PhaseSeedsFixture.sol";
import { FANtiumAthletesV12 } from "src/FANtiumAthletesV12.sol";
import { Collection, PhaseSeed, SaleStatus } from "src/interfaces/IFANtiumAthletes.sol";

/**
 * @notice V11 collection shape, as returned by the currently deployed mainnet implementation.
 */
struct CollectionV11 {
    bool exists;
    uint256 launchTimestamp;
    bool isMintable;
    bool isPaused;
    uint24 invocations;
    uint256 price;
    uint256 maxInvocations;
    uint256 tournamentEarningShare1e7;
    address payable athleteAddress;
    uint256 athletePrimarySalesBPS;
    uint256 athleteSecondarySalesBPS;
    address payable UNUSED_fantiumSalesAddress;
    uint256 fantiumSecondarySalesBPS;
    uint256 otherEarningShare1e7;
}

interface IFANtiumAthletesV11 {
    function collections(uint256 collectionId) external view returns (CollectionV11 memory);
    function nextCollectionId() external view returns (uint256);
}

/**
 * @notice Rehearses the V11 -> V12 mainnet upgrade against forked Polygon state: deploys the V12
 *         implementation, executes `upgradeToAndCall(initializeV12(seeds))` as the FANtium Safe
 *         with the Strapi-derived phase seeds from `test/fixtures/phase-seeds.json`, and verifies
 *         every collection's phases/status migration — including that the price charged by the
 *         active phase equals the pre-upgrade on-chain price (no pricing change at cutover).
 *         Skipped when ALCHEMY_API_KEY is not set (e.g. public CI).
 */
contract UpgradeMainnetV12ForkTest is Test {
    address public constant FANTIUM_ATHLETES_PROXY = 0x2b98132E7cfd88C5D854d64f436372838A9BA49d;
    /// @notice FANtium Safe, holder of DEFAULT_ADMIN_ROLE on the proxy.
    address public constant FANTIUM_SAFE = 0x417834e4371610BB81DC150fF47C0859b72318B0;

    /// @notice EIP-1967 implementation slot, used to detect whether the upgrade already happened.
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    /// @notice The V11 implementation the rehearsal upgrades from.
    address private constant _V11_IMPLEMENTATION = 0x6f4cd162708Eb3675da1244Eeb322A43d6f3454c;

    function test_fork_upgradeMainnetV12_migratesAllCollections() public {
        vm.skip(bytes(vm.envOr("ALCHEMY_API_KEY", string(""))).length == 0);
        vm.createSelectFork(vm.rpcUrl("polygon"));

        // The rehearsal only applies while mainnet still runs V11. Once the Safe has executed the
        // upgrade (2026-07-22), initializeV12 is consumed on-chain and this scenario is history.
        address currentImplementation = address(uint160(uint256(vm.load(FANTIUM_ATHLETES_PROXY, _IMPLEMENTATION_SLOT))));
        vm.skip(currentImplementation != _V11_IMPLEMENTATION);

        IFANtiumAthletesV11 v11 = IFANtiumAthletesV11(FANTIUM_ATHLETES_PROXY);
        uint256 nextCollectionId = v11.nextCollectionId();
        assertGt(nextCollectionId, 1, "no collections on mainnet?");

        // Snapshot the pre-upgrade state.
        CollectionV11[] memory pre = new CollectionV11[](nextCollectionId);
        for (uint256 id = 1; id < nextCollectionId; id++) {
            pre[id] = v11.collections(id);
        }

        // Index the Strapi-derived phase seeds by collection id.
        PhaseSeed[] memory seeds = PhaseSeedsFixture.load(vm);
        assertGt(seeds.length, 0, "phase seeds fixture is empty");
        PhaseSeed[] memory seedByCollectionId = new PhaseSeed[](nextCollectionId);
        for (uint256 i = 0; i < seeds.length; i++) {
            assertLt(seeds[i].collectionId, nextCollectionId, "seed for unknown collection");
            seedByCollectionId[seeds[i].collectionId] = seeds[i];
        }

        // Upgrade + migrate atomically, exactly as the Safe will.
        FANtiumAthletesV12 implementation = new FANtiumAthletesV12();
        uint256 gasBefore = gasleft();
        vm.prank(FANTIUM_SAFE);
        UUPSUpgradeable(FANTIUM_ATHLETES_PROXY)
            .upgradeToAndCall(address(implementation), abi.encodeCall(FANtiumAthletesV12.initializeV12, (seeds)));
        emit log_named_uint("upgradeToAndCall(initializeV12) gas", gasBefore - gasleft());

        // Verify the migration, collection by collection.
        FANtiumAthletesV12 v12 = FANtiumAthletesV12(FANTIUM_ATHLETES_PROXY);
        for (uint256 id = 1; id < nextCollectionId; id++) {
            if (!pre[id].exists) {
                continue;
            }

            Collection memory post = v12.collections(id);
            assertEq(post.invocations, pre[id].invocations, "invocations changed");

            SaleStatus expected;
            if (pre[id].isMintable) {
                // Legacy "paused" sales were all meant to be closed; the migration closes them.
                expected = pre[id].isPaused ? SaleStatus.Closed : SaleStatus.Open;
            } else {
                expected = pre[id].invocations > 0 ? SaleStatus.Closed : SaleStatus.Pending;
            }
            assertEq(uint256(post.status), uint256(expected), "status mismatch");

            PhaseSeed memory seed = seedByCollectionId[id];
            if (seed.phases.length == 0) {
                // No Strapi discount schedule: single phase from the legacy on-chain values.
                assertEq(post.phases.length, 1, "phases not seeded");
                assertEq(post.phases[0].price, pre[id].price, "price mismatch");
                assertEq(post.phases[0].maxInvocations, pre[id].maxInvocations, "maxInvocations mismatch");
                continue;
            }

            // Strapi discount schedule injected.
            assertEq(post.phases.length, seed.phases.length, "seeded phases length mismatch");
            uint256 cumulative = 0;
            uint256 activePhasePrice = 0;
            for (uint256 j = 0; j < seed.phases.length; j++) {
                assertEq(post.phases[j].price, seed.phases[j].price, "seeded phase price mismatch");
                assertEq(post.phases[j].maxInvocations, seed.phases[j].maxInvocations, "seeded phase supply mismatch");
                if (activePhasePrice == 0 && pre[id].invocations < cumulative + seed.phases[j].maxInvocations) {
                    activePhasePrice = seed.phases[j].price;
                }
                cumulative += seed.phases[j].maxInvocations;
            }
            assertGe(cumulative, pre[id].invocations, "seeded supply below invocations");

            // Price continuity: an open, non-sold-out sale must keep charging exactly what the
            // legacy single price charged at the moment of the upgrade.
            if (pre[id].isMintable && !pre[id].isPaused && pre[id].invocations < cumulative) {
                assertEq(activePhasePrice, pre[id].price, "active phase price differs from on-chain price");
            }
        }

        // The migration cannot run twice.
        PhaseSeed[] memory noSeeds = new PhaseSeed[](0);
        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(FANTIUM_SAFE);
        v12.initializeV12(noSeeds);
    }
}
