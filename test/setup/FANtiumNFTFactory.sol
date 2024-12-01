// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Collection, CreateCollection} from "../../src/interfaces/IFANtiumNFT.sol";
import {FANtiumNFTV5} from "../../src/FANtiumNFTV5.sol";
import {UnsafeUpgrades} from "../../src/upgrades/UnsafeUpgrades.sol";
import {BaseTest} from "../BaseTest.sol";
import {FANtiumUserManagerFactory} from "./FANtiumUserManagerFactory.sol";

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

contract FANtiumNFTFactory is BaseTest, FANtiumUserManagerFactory {
    address public fantiumNFT_admin = makeAddr("admin");
    address public fantiumNFT_platformManager = makeAddr("platformManager");
    address public fantiumNFT_upgrader = makeAddr("upgrader");
    address public fantiumNFT_trustedForwarder = makeAddr("trustedForwarder");
    address payable public fantiumNFT_athlete = payable(makeAddr("athlete"));
    address payable public fantiumNFT_treasuryPrimary = payable(makeAddr("treasuryPrimary"));
    address payable public fantiumNFT_treasurySecondary = payable(makeAddr("treasurySecondary"));

    ERC20 public usdc;
    address public fantiumNFT_implementation;
    address public fantiumNFT_proxy;
    FANtiumNFTV5 public fantiumNFT;

    function setUp() public virtual override {
        usdc = new ERC20("USD Coin", "USDC");
        fantiumNFT_implementation = address(new FANtiumNFTV5());
        fantiumNFT_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumNFT_implementation, abi.encodeCall(FANtiumNFTV5.initialize, (admin, "FANtium", "FAN"))
        );
        fantiumNFT = FANtiumNFTV5(fantiumNFT_proxy);

        // Configure roles
        vm.startPrank(admin);
        fantiumNFT.grantRole(fantiumNFT.UPGRADER_ROLE(), fantiumNFT_upgrader);
        fantiumNFT.grantRole(fantiumNFT.PLATFORM_MANAGER_ROLE(), fantiumNFT_platformManager);
        vm.stopPrank();

        vm.startPrank(fantiumNFT_platformManager);
        fantiumNFT.setTrustedForwarder(fantiumNFT_trustedForwarder);
        fantiumNFT.setERC20PaymentToken(address(usdc));

        // Configure collections
        CollectionJson[] memory collections = abi.decode(loadFixture("collections.json"), (CollectionJson[]));
        for (uint256 i = 0; i < collections.length; i++) {
            CollectionJson memory collection = collections[i];
            fantiumNFT.createCollection(
                CreateCollection({
                    athleteAddress: collection.athleteAddress,
                    athletePrimarySalesBPS: collection.athletePrimarySalesBPS,
                    athleteSecondarySalesBPS: collection.athleteSecondarySalesBPS,
                    fantiumSalesAddress: collection.fantiumSalesAddress,
                    fantiumSecondarySalesBPS: collection.fantiumSecondarySalesBPS,
                    launchTimestamp: collection.launchTimestamp,
                    maxInvocations: collection.maxInvocations,
                    otherEarningShare1e7: collection.otherEarningShare1e7,
                    price: collection.price,
                    tournamentEarningShare1e7: collection.tournamentEarningShare1e7
                })
            );
        }
        vm.stopPrank();
    }
}
