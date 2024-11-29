// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {FANtiumNFTV5} from "../src/FANtiumNFTV5.sol";
import {FANtiumNFTFactory} from "./setup/FANtiumNFTFactory.sol";
import {UnsafeUpgrades} from "../src/upgrades/UnsafeUpgrades.sol";

contract FANtiumNFTV5Test is Test {
    FANtiumNFTV5 public fantiumNFT;
    ERC20 public usdc;

    address public admin = makeAddr("admin");
    address public upgrader = makeAddr("upgrader");
    address public trustedForwarder = makeAddr("trustedForwarder");
    address payable public treasuryPrimary = payable(makeAddr("treasuryPrimary"));
    address payable public treasurySecondary = payable(makeAddr("treasurySecondary"));

    address public other = makeAddr("other");
    address public user1 = makeAddr("user1");
    address payable public athlete = payable(makeAddr("athlete"));

    uint256 public collectionId;

    function setUp() public {
        usdc = new ERC20("USD Coin", "USDC");
        FANtiumNFTFactory factory = new FANtiumNFTFactory(usdc);
        fantiumNFT = factory.instance();
    }

    function testName() public view {
        assertEq(fantiumNFT.name(), "FANtium");
    }

    function testSymbol() public view {
        assertEq(fantiumNFT.symbol(), "FAN");
    }

    function testMintToken() public {
        // vm.startPrank(admin);
        // fantiumNFT.mint(user1, 1);
        // vm.stopPrank();
    }
}
