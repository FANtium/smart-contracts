// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";
import {FootballTokenV1} from "src/FootballTokenV1.sol";
import {FootballCollection, FootballCollectionData} from "src/interfaces/IFootballTokenV1.sol";
import {UnsafeUpgrades} from "src/upgrades/UnsafeUpgrades.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock ERC20", "ERC20") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

contract FootballTokenV1Setup is BaseTest {
    address public admin = makeAddr("admin");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");
    address public OutOfCashuser = makeAddr("OutOfCashuser");

    address public team = makeAddr("team");

    MockUSDC public usdc;
    MockERC20 public erc20;

    address public football_implementation;
    address public football_proxy;
    FootballTokenV1 public footballToken;

    function setUp() public virtual {
        football_implementation = address(new FootballTokenV1());
        football_proxy = UnsafeUpgrades.deployUUPSProxy(
            football_implementation,
            abi.encodeCall(FootballTokenV1.initialize, (admin))
        );
        footballToken = FootballTokenV1(football_proxy);

        // Deploy mock USDC
        usdc = new MockUSDC();
        erc20 = new MockERC20();

        // Setup accepted tokens
        address[] memory tokens = new address[](1);
        tokens[0] = address(usdc);
        vm.prank(admin);
        footballToken.setAcceptedTokens(tokens, true);

        // Give user some USDC
        usdc.transfer(user, 10000 * 10 ** 6);
        usdc.transfer(user2, 10000 * 10 ** 6);
    }
}

contract FootballTokenV1Test is FootballTokenV1Setup {
    function test_Initialize() public {
        assertEq(footballToken.owner(), admin);
        assertEq(footballToken.treasury(), admin);
        assertEq(footballToken.name(), "FANtium Football");
        assertEq(footballToken.symbol(), "FANT");
    }

    function test_CreateCollection() public {
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        footballToken.createCollection(collection);

        assertEq(footballToken.nextCollectionIndex(), 1);
    }

    function test_MintToken() public {
        // Create collection first
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        footballToken.createCollection(collection);

        // Approve USDC spending
        vm.startPrank(user);
        usdc.approve(address(footballToken), type(uint256).max);

        // Warp to start date
        vm.warp(block.timestamp + 1 days);

        // Mint token
        footballToken.mintTo(1, 1, user, address(usdc));
        vm.stopPrank();

        assertEq(footballToken.balanceOf(user), 1);
        assertEq(footballToken.ownerOf(0), user);
    }

    function test_MultipleMintToken() public {
        // Create collection first
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        footballToken.createCollection(collection);

        // Approve USDC spending
        vm.startPrank(user);
        usdc.approve(address(footballToken), type(uint256).max);

        // Warp to start date
        vm.warp(block.timestamp + 1 days);

        // Mint token
        footballToken.mintTo(1, 5, user, address(usdc));
        vm.stopPrank();

        assertEq(footballToken.balanceOf(user), 5);
        assertEq(footballToken.ownerOf(0), user);
        assertEq(footballToken.ownerOf(1), user);
        assertEq(footballToken.ownerOf(2), user);
        assertEq(footballToken.ownerOf(3), user);
        assertEq(footballToken.ownerOf(4), user);
    }

    function testFail_MintBeforeStartDate() public {
        // Create collection first
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        footballToken.createCollection(collection);

        // Try to mint before start date
        vm.prank(user);
        footballToken.mintTo(1, 1, user, address(usdc));
    }

    function testFail_MintAfterClosedDate() public {
        // Create collection first
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        footballToken.createCollection(collection);

        // Warp to start date
        vm.warp(block.timestamp + 8 days);

        // Try to mint after closed date
        vm.prank(user);
        footballToken.mintTo(1, 1, user, address(usdc));
    }
}
