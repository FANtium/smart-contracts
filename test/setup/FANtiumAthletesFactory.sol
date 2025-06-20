// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { FANtiumAthletesV9 } from "src/FANtiumAthletesV9.sol";
import { Collection, CollectionData } from "src/interfaces/IFANtiumAthletes.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "test/BaseTest.sol";

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

contract FANtiumAthletesFactory is BaseTest {
    using ECDSA for bytes32;

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
    FANtiumAthletesV9 public fantiumAthletes;

    function setUp() public virtual {
        (fantiumAthletes_signer, fantiumAthletes_signerKey) = makeAddrAndKey("rewarder");

        usdc = new ERC20("USD Coin", "USDC");
        fantiumAthletes_implementation = address(new FANtiumAthletesV9());
        fantiumAthletes_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumAthletes_implementation, abi.encodeCall(FANtiumAthletesV9.initialize, (fantiumAthletes_admin))
        );
        fantiumAthletes = FANtiumAthletesV9(fantiumAthletes_proxy);

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
                    maxInvocations: collection.maxInvocations,
                    otherEarningShare1e7: collection.otherEarningShare1e7,
                    price: collection.price,
                    tournamentEarningShare1e7: collection.tournamentEarningShare1e7
                })
            );

            // By default, collections are not mintable, set them as mintable/paused if needed
            fantiumAthletes.setCollectionStatus(collectionId, collection.isMintable, collection.isPaused);
        }
        vm.stopPrank();
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
        amountUSDC = collection.price * quantity * 10 ** usdc.decimals();

        (fantiumRevenue, fantiumAddress, athleteRevenue, athleteAddress) =
            fantiumAthletes.getPrimaryRevenueSplits(collectionId, amountUSDC);
        if (block.timestamp < collection.launchTimestamp) {
            vm.warp(collection.launchTimestamp + 1);
        }

        deal(address(usdc), recipient, amountUSDC);

        vm.prank(recipient);
        usdc.approve(address(fantiumAthletes), amountUSDC);
    }

    function prepareSale(
        uint256 collectionId,
        uint24 quantity,
        address recipient,
        uint256 amountUSDC
    )
        public
        returns (
            bytes memory signature,
            uint256 nonce,
            uint256 fantiumRevenue,
            address fantiumAddress,
            uint256 athleteRevenue,
            address athleteAddress
        )
    {
        Collection memory collection = fantiumAthletes.collections(collectionId);
        (fantiumRevenue, fantiumAddress, athleteRevenue, athleteAddress) =
            fantiumAthletes.getPrimaryRevenueSplits(collectionId, amountUSDC);
        nonce = fantiumAthletes.nonces(recipient);

        if (block.timestamp < collection.launchTimestamp) {
            vm.warp(collection.launchTimestamp + 1);
        }

        deal(address(usdc), recipient, amountUSDC);

        vm.prank(recipient);
        usdc.approve(address(fantiumAthletes), amountUSDC);

        return (
            signMint(recipient, nonce, collectionId, quantity, amountUSDC),
            nonce,
            fantiumRevenue,
            fantiumAddress,
            athleteRevenue,
            athleteAddress
        );
    }

    function mintTo(uint256 collectionId, uint24 quantity, address recipient) public returns (uint256 lastTokenId) {
        prepareSale(collectionId, quantity, recipient);
        vm.prank(recipient);
        return fantiumAthletes.mintTo(collectionId, quantity, recipient);
    }

    function signMint(
        address recipient,
        uint256 nonce,
        uint256 collectionId,
        uint24 quantity,
        uint256 amount
    )
        public
        view
        returns (bytes memory)
    {
        bytes32 hash = keccak256(abi.encode(collectionId, quantity, recipient, amount, nonce)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fantiumAthletes_signerKey, hash);
        return abi.encodePacked(r, s, v);
    }
}
