// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { FANtiumMarketplaceV1 } from "../../src/FANtiumMarketplaceV1.sol";
import { Offer } from "../../src/interfaces/IFANtiumMarketplace.sol";

import { UnsafeUpgrades } from "../../src/upgrades/UnsafeUpgrades.sol";

import { FANtiumNFTFactory } from "./FANtiumNFTFactory.t.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { BaseTest } from "test/BaseTest.sol";

contract FANtiumMarketplaceFactory is BaseTest, FANtiumNFTFactory {
    // addresses
    address public fantiumMarketplace_admin = makeAddr("admin");
    address public fantiumMarketplace_implementation;
    address public fantiumMarketplace_proxy;

    // events
    event TreasuryAddressUpdate(address newWalletAddress);
    event OfferExecuted(Offer offer, address indexed buyer);

    // contracts
    FANtiumMarketplaceV1 public fantiumMarketplace;

    function setUp() public virtual override {
        FANtiumNFTFactory.setUp();

        fantiumMarketplace_implementation = address(new FANtiumMarketplaceV1());

        fantiumMarketplace_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumMarketplace_implementation,
            abi.encodeCall(FANtiumMarketplaceV1.initialize, (fantiumMarketplace_admin, address(usdc)))
        );

        fantiumMarketplace = FANtiumMarketplaceV1(fantiumMarketplace_proxy);

        // we set usdc in FANtiumNFTFactory
    }
}
