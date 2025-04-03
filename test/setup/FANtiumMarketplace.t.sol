// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { FANtiumMarketplaceV1 } from "../../src/FANtiumMarketplaceV1.sol";
import { Offer } from "../../src/interfaces/IFANtiumMarketplace.sol";

import { UnsafeUpgrades } from "../../src/upgrades/UnsafeUpgrades.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { BaseTest } from "test/BaseTest.sol";

contract FANtiumMarketplaceFactory is BaseTest {
    // addresses
    address public fantiumMarketplace_admin = makeAddr("admin");
    address public fantiumMarketplace_implementation;
    address public fantiumMarketplace_proxy;

    // events
    event TreasuryAddressUpdate(address newWalletAddress);
    event OfferExecuted(Offer offer, address indexed buyer);

    // contracts
    FANtiumMarketplaceV1 public fantiumMarketplace;
    ERC20 public usdc;

    function setUp() public virtual {
        fantiumMarketplace_implementation = address(new FANtiumMarketplaceV1());

        fantiumMarketplace_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumMarketplace_implementation,
            abi.encodeCall(FANtiumMarketplaceV1.initialize, (fantiumMarketplace_admin, address(usdc)))
        );

        fantiumMarketplace = FANtiumMarketplaceV1(fantiumMarketplace_proxy);

        usdc = new ERC20("USD Coin", "USDC");
    }
}
