// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { FANtiumTokenV1 } from "../../src/FANtiumTokenV1.sol";
import { UnsafeUpgrades } from "../../src/upgrades/UnsafeUpgrades.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { BaseTest } from "test/BaseTest.sol";

contract FANtiumTokenFactory is BaseTest {
    // addresses
    address public fantiumToken_admin = makeAddr("admin");
    address public fantiumToken_implementation;
    address public fantiumToken_proxy;

    // events
    event FANtiumTokenSale(uint256 quantity, address indexed recipient, uint256 amount);
    event TreasuryAddressUpdate(address newWalletAddress);

    // contracts
    FANtiumTokenV1 public fantiumToken;
    ERC20 public usdc;

    function setUp() public virtual {
        fantiumToken_implementation = address(new FANtiumTokenV1());

        fantiumToken_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumToken_implementation, abi.encodeCall(FANtiumTokenV1.initialize, (fantiumToken_admin))
        );

        fantiumToken = FANtiumTokenV1(fantiumToken_proxy);

        usdc = new ERC20("USD Coin", "USDC");
    }
}
