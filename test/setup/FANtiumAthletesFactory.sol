// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
    IERC20MetadataUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FANtiumAthletesV12 } from "src/FANtiumAthletesV12.sol";
import { Collection, CollectionData, PricePhase, SaleStatus } from "src/interfaces/IFANtiumAthletes.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "test/BaseTest.sol";
import { EIP712Domain, EIP712Signer } from "test/utils/EIP712Signer.sol";

/**
 * @notice Collection data structure for deserialization.
 * We cannot use the Collection struct because Foundry requires fields of the struct to be in alphabetical order.
 */
struct CollectionJson {
    address payable athleteAddress;
    uint256 athletePrimarySalesBPS;
    uint256 athleteSecondarySalesBPS;
    bool exists;
    address payable fantiumSalesAddress;
    uint256 fantiumSecondarySalesBPS;
    uint24 invocations;
    bool isMintable;
    bool isPaused;
    uint256 launchTimestamp;
    uint256 maxInvocations;
    uint256 otherEarningShare1e7;
    uint256 price;
    uint256 tournamentEarningShare1e7;
}

contract FANtiumAthletesFactory is BaseTest, EIP712Signer {
    address public fantiumAthletes_admin = makeAddr("admin");
    address public fantiumAthletes_trustedForwarder = makeAddr("trustedForwarder");
    address payable public fantiumAthletes_athlete = payable(makeAddr("athlete"));
    address payable public fantiumAthletes_treasuryPrimary = payable(makeAddr("treasuryPrimary"));
    address payable public fantiumAthletes_treasurySecondary = payable(makeAddr("treasurySecondary"));
    address public fantiumAthletes_tokenUpgrader = makeAddr("tokenUpgrader");
    address public fantiumAthletes_signer;
    uint256 public fantiumAthletes_signerKey;

    ERC20 public usdc;
    address public fantiumAthletes_implementation;
    address public fantiumAthletes_proxy;
    FANtiumAthletesV12 public fantiumAthletes;

    function setUp() public virtual {
        (fantiumAthletes_signer, fantiumAthletes_signerKey) = makeAddrAndKey("rewarder");

        usdc = new ERC20("USD Coin", "USDC");
        fantiumAthletes_implementation = address(new FANtiumAthletesV12());
        fantiumAthletes_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumAthletes_implementation, abi.encodeCall(FANtiumAthletesV12.initialize, (fantiumAthletes_admin))
        );
        fantiumAthletes = FANtiumAthletesV12(fantiumAthletes_proxy);

        // Configure roles
        vm.startPrank(fantiumAthletes_admin);
        fantiumAthletes.grantRole(fantiumAthletes.FORWARDER_ROLE(), fantiumAthletes_trustedForwarder);
        fantiumAthletes.grantRole(fantiumAthletes.SIGNER_ROLE(), fantiumAthletes_signer);
        fantiumAthletes.grantRole(fantiumAthletes.TOKEN_UPGRADER_ROLE(), fantiumAthletes_tokenUpgrader);
        fantiumAthletes.setERC20PaymentToken(IERC20MetadataUpgradeable(address(usdc)));
        fantiumAthletes.setBaseURI("https://app.fantium.com/api/metadata/");
        fantiumAthletes.setTreasury(fantiumAthletes_treasuryPrimary);

        // Configure collections
        CollectionJson[] memory collections = abi.decode(loadFixture("collections.json"), (CollectionJson[]));
        for (uint256 i = 0; i < collections.length; i++) {
            CollectionJson memory collection = collections[i];
            uint256 collectionId = fantiumAthletes.createCollection(
                CollectionData({
                    athleteAddress: collection.athleteAddress,
                    athletePrimarySalesBPS: collection.athletePrimarySalesBPS,
                    athleteSecondarySalesBPS: collection.athleteSecondarySalesBPS,
                    fantiumSecondarySalesBPS: collection.fantiumSecondarySalesBPS,
                    launchTimestamp: collection.launchTimestamp,
                    otherEarningShare1e7: collection.otherEarningShare1e7,
                    phases: singlePhase(collection.price, collection.maxInvocations),
                    tournamentEarningShare1e7: collection.tournamentEarningShare1e7
                })
            );

            // By default, collections are Pending; map the fixture's legacy booleans to a SaleStatus.
            fantiumAthletes.setSaleStatus(
                singleCollection(collectionId), saleStatusFromLegacyFlags(collection.isMintable, collection.isPaused)
            );
        }
        vm.stopPrank();
    }

    /**
     * @notice Maps the legacy (isMintable, isPaused) booleans of the fixtures to a SaleStatus.
     * @dev Deliberately keeps paused fixtures `Paused` (unlike `_migrateCollectionV12`, which
     *      closes legacy-paused sales as a one-time business decision) so the test environment
     *      retains collections exercising the `SaleStatus.Paused` code paths.
     */
    function saleStatusFromLegacyFlags(bool isMintable, bool isPaused) public pure returns (SaleStatus) {
        if (isMintable) {
            return isPaused ? SaleStatus.Paused : SaleStatus.Open;
        }
        return SaleStatus.Pending;
    }

    /**
     * @notice Wraps a single collection ID into the array expected by `setSaleStatus`.
     */
    function singleCollection(uint256 collectionId) public pure returns (uint256[] memory collectionIds) {
        collectionIds = new uint256[](1);
        collectionIds[0] = collectionId;
    }

    /**
     * @notice Builds a one-element phases array from a legacy single-tier (price, maxInvocations) config.
     */
    function singlePhase(uint256 price, uint256 maxInvocations) public pure returns (PricePhase[] memory phases) {
        phases = new PricePhase[](1);
        phases[0] = PricePhase({ price: uint128(price), maxInvocations: uint128(maxInvocations) });
    }

    /**
     * @notice Mirrors the contract's active-phase resolution for test-side assertions.
     */
    function activePhase(uint256 collectionId)
        public
        view
        returns (uint256 index, PricePhase memory phase, uint256 cumulativeUpToEnd)
    {
        Collection memory collection = fantiumAthletes.collections(collectionId);
        uint256 cumulative = 0;
        for (uint256 i = 0; i < collection.phases.length; i++) {
            cumulative += collection.phases[i].maxInvocations;
            if (collection.invocations < cumulative) {
                return (i, collection.phases[i], cumulative);
            }
        }
        revert("all phases consumed");
    }

    /**
     * @notice Remaining mintable supply across all phases of a collection.
     */
    function remainingSupply(uint256 collectionId) public view returns (uint256 remaining) {
        Collection memory collection = fantiumAthletes.collections(collectionId);
        uint256 total = 0;
        for (uint256 i = 0; i < collection.phases.length; i++) {
            total += collection.phases[i].maxInvocations;
        }
        remaining = total - collection.invocations;
    }

    function prepareSale(
        uint256 collectionId,
        uint24 quantity,
        address recipient
    )
        public
        returns (
            uint256 amountUSDC,
            uint256 fantiumRevenue,
            address payable fantiumAddress,
            uint256 athleteRevenue,
            address payable athleteAddress
        )
    {
        Collection memory collection = fantiumAthletes.collections(collectionId);
        (amountUSDC,,,) = fantiumAthletes.quoteMint(collectionId, quantity);

        (fantiumRevenue, fantiumAddress, athleteRevenue, athleteAddress) =
            fantiumAthletes.getPrimaryRevenueSplits(collectionId, amountUSDC);
        if (block.timestamp < collection.launchTimestamp) {
            vm.warp(collection.launchTimestamp + 1);
        }

        deal(address(usdc), recipient, amountUSDC);

        vm.prank(recipient);
        usdc.approve(address(fantiumAthletes), amountUSDC);
    }

    /**
     * @notice Prepares a signed sale: quotes via the contract, funds and approves the recipient
     *         for the quoted amount, and signs the mint authorization.
     */
    function prepareSignedSale(
        uint256 collectionId,
        uint24 quantity,
        address recipient
    )
        public
        returns (uint256 amountUSDC, uint256 deadline, bytes memory signature)
    {
        Collection memory collection = fantiumAthletes.collections(collectionId);
        (amountUSDC,,,) = fantiumAthletes.quoteMint(collectionId, quantity);

        if (block.timestamp < collection.launchTimestamp) {
            vm.warp(collection.launchTimestamp + 1);
        }

        deal(address(usdc), recipient, amountUSDC);

        vm.prank(recipient);
        usdc.approve(address(fantiumAthletes), amountUSDC);

        deadline = block.timestamp + 1 hours;
        signature = signMint(recipient, fantiumAthletes.nonces(recipient), collectionId, quantity, deadline);
    }

    /**
     * @notice Mints `quantity` tokens through the signed flow (the only mint entry point):
     *         quotes, funds, approves, signs, and mints.
     */
    function mintTo(uint256 collectionId, uint24 quantity, address recipient) public returns (uint256 lastTokenId) {
        (, uint256 deadline, bytes memory signature) = prepareSignedSale(collectionId, quantity, recipient);
        vm.prank(recipient);
        return fantiumAthletes.mintTo(collectionId, quantity, recipient, deadline, signature);
    }

    /**
     * @notice EIP-712 domain matching `FANtiumAthletesV12`.
     */
    function fantiumAthletesDomain() public view returns (EIP712Domain memory) {
        return EIP712Domain({
            name: "FANtium Athletes", version: "1", chainId: block.chainid, verifyingContract: address(fantiumAthletes)
        });
    }

    function signMint(
        address recipient,
        uint256 nonce,
        uint256 collectionId,
        uint24 quantity,
        uint256 deadline
    )
        public
        view
        returns (bytes memory)
    {
        bytes32 structHash =
            keccak256(abi.encode(fantiumAthletes.MINT_TYPEHASH(), collectionId, quantity, recipient, nonce, deadline));
        return typedSignPacked(fantiumAthletes_signerKey, fantiumAthletesDomain(), structHash);
    }
}
