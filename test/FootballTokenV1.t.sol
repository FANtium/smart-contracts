// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseTest} from "test/BaseTest.sol";
import {FootballTokenV1} from "src/FootballTokenV1.sol";
import {FootballCollection, FootballCollectionData, MintErrorReason, IFootballTokenV1} from "src/interfaces/IFootballTokenV1.sol";
import {UnsafeUpgrades} from "src/upgrades/UnsafeUpgrades.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock ERC20", "ERC20") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
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
        usdc.transfer(user, 10_000 * 10 ** 6);
        erc20.transfer(user, 10_000 * 10 ** 18);
        usdc.transfer(user2, 10_000 * 10 ** 6);
    }
}

contract FootballTokenV1Test is FootballTokenV1Setup {
    function test_initialize_ok() public {
        assertEq(footballToken.owner(), admin);
        assertEq(footballToken.treasury(), admin);
        assertEq(footballToken.name(), "FANtium Football");
        assertEq(footballToken.symbol(), "FANT");
    }

    function test_createCollection_ok() public {
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 700,
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

    function test_updateCollection_ok() public {
        // Create initial collection
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 700,
            maxSupply: 100,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        footballToken.createCollection(collection);

        // Update collection
        FootballCollectionData memory updatedCollection = FootballCollectionData({
            name: "Updated Collection",
            priceUSD: 800,
            maxSupply: 200,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 14 days,
            isPaused: true,
            team: makeAddr("newTeam")
        });

        vm.prank(admin);
        footballToken.updateCollection(1, updatedCollection);

        (
            string memory name,
            uint256 priceUSD,
            uint256 supply,
            uint256 maxSupply,
            uint256 startDate,
            uint256 closeDate,
            bool isPaused,
            address team
        ) = footballToken.collections(1);
        assertEq(name, "Updated Collection");
        assertEq(priceUSD, 800);
        assertEq(supply, 0);
        assertEq(maxSupply, 200);
        assertEq(startDate, block.timestamp + 1 days);
        assertEq(closeDate, block.timestamp + 14 days);
        assertEq(isPaused, true);
        assertEq(team, makeAddr("newTeam"));
    }

    function test_setAcceptedTokens_ok() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(usdc);
        tokens[1] = address(erc20);

        vm.prank(admin);
        footballToken.setAcceptedTokens(tokens, true);

        // Try minting with both tokens to verify they're accepted
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        footballToken.createCollection(collection);

        vm.startPrank(user);
        usdc.approve(address(footballToken), type(uint256).max);
        erc20.approve(address(footballToken), type(uint256).max);

        footballToken.mintTo(0, 1, user, address(usdc));
        footballToken.mintTo(0, 1, user, address(erc20));
        vm.stopPrank();
    }

    function test_setPauseCollection_ok() public {
        // Create collection
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        footballToken.createCollection(collection);

        // Pause collection
        vm.prank(admin);
        footballToken.setPauseCollection(1, true);

        (, , , , , , bool isPaused, ) = footballToken.collections(1);

        assertTrue(isPaused);

        // Unpause collection
        vm.prank(admin);
        footballToken.setPauseCollection(1, false);

        (, , , , , , bool isPausedUpdated, ) = footballToken.collections(1);
        assertFalse(isPausedUpdated);
    }

    function test_mintTo_ok() public {
        // Create collection first
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp,
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
        footballToken.mintTo(0, 1, user, address(usdc));
        vm.stopPrank();

        assertEq(footballToken.balanceOf(user), 1);
        assertEq(footballToken.ownerOf(0), user);
    }

    function test_mintTo_ok_multiple() public {
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
        footballToken.mintTo(0, 5, user, address(usdc));
        vm.stopPrank();

        assertEq(footballToken.balanceOf(user), 5);
        assertEq(footballToken.ownerOf(0), user);
        assertEq(footballToken.ownerOf(1), user);
        assertEq(footballToken.ownerOf(2), user);
        assertEq(footballToken.ownerOf(3), user);
        assertEq(footballToken.ownerOf(4), user);
    }

    function test_mintTo_ok_multiplePeople() public {
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
        vm.prank(user);
        usdc.approve(address(footballToken), type(uint256).max);
        vm.prank(user2);
        usdc.approve(address(footballToken), type(uint256).max);

        // Warp to start date
        vm.warp(block.timestamp + 1 days);

        // Mint token
        vm.prank(user);
        footballToken.mintTo(0, 1, user, address(usdc));
        vm.prank(user2);
        footballToken.mintTo(0, 1, user2, address(usdc));
        vm.prank(user);
        footballToken.mintTo(0, 1, user, address(usdc));
        vm.prank(user2);
        footballToken.mintTo(0, 1, user2, address(usdc));
        vm.prank(user);
        footballToken.mintTo(0, 1, user, address(usdc));
        vm.prank(user2);
        footballToken.mintTo(0, 1, user2, address(usdc));

        assertEq(footballToken.balanceOf(user), 3);
        assertEq(footballToken.balanceOf(user2), 3);

        assertEq(footballToken.ownerOf(0), user);
        assertEq(footballToken.ownerOf(1), user2);
        assertEq(footballToken.ownerOf(2), user);
        assertEq(footballToken.ownerOf(3), user2);
        assertEq(footballToken.ownerOf(4), user);
        assertEq(footballToken.ownerOf(5), user2);
    }

    function test_mintTo_ok_twoCollections() public {
        // Create first collection
        FootballCollectionData memory collection1 = FootballCollectionData({
            name: "Test Collection 1",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        // Create second collection
        FootballCollectionData memory collection2 = FootballCollectionData({
            name: "Test Collection 2",
            priceUSD: 200,
            maxSupply: 50,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        // Create both collections
        vm.startPrank(admin);
        footballToken.createCollection(collection1);
        footballToken.createCollection(collection2);
        vm.stopPrank();

        (string memory name, , , , , , , ) = footballToken.collections(0);
        (string memory name2, , , , , , , ) = footballToken.collections(1);

        assertEq(name, "Test Collection 1");
        assertEq(name2, "Test Collection 2");

        // Approve USDC spending
        vm.prank(user);
        usdc.approve(address(footballToken), type(uint256).max);

        // Warp to start date
        vm.warp(block.timestamp + 1 days);

        // Mint one token from each collection
        vm.startPrank(user);
        footballToken.mintTo(0, 1, user, address(usdc));
        footballToken.mintTo(1, 1, user, address(usdc));
        vm.stopPrank();

        // Assert user owns one token from each collection
        assertEq(footballToken.balanceOf(user), 2);
        assertEq(footballToken.ownerOf(0), user);
        assertEq(footballToken.ownerOf(1), user);

        // // Assert tokens are from different collections
        assertEq(footballToken.tokenToCollection(0), 0);
        assertEq(footballToken.tokenToCollection(1), 1);
    }

    function test_mintTo_ok_multiplePeopleAndCollection() public {
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

        FootballCollectionData memory collection2 = FootballCollectionData({
            name: "Test Collection 2",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.startPrank(admin);
        footballToken.createCollection(collection);
        footballToken.createCollection(collection2);
        vm.stopPrank();

        // Approve USDC spending
        vm.prank(user);
        usdc.approve(address(footballToken), type(uint256).max);
        vm.prank(user2);
        usdc.approve(address(footballToken), type(uint256).max);

        // Warp to start date
        vm.warp(block.timestamp + 1 days);

        // Mint token
        vm.prank(user); //0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D
        footballToken.mintTo(0, 1, user, address(usdc));
        vm.prank(user2); // 0x537C8f3d3E18dF5517a58B3fB9D9143697996802
        footballToken.mintTo(0, 1, user2, address(usdc));
        vm.prank(user);
        footballToken.mintTo(1, 1, user, address(usdc));
        vm.prank(user2);
        footballToken.mintTo(1, 1, user2, address(usdc));
        vm.prank(user);
        footballToken.mintTo(0, 1, user, address(usdc));
        vm.prank(user2);
        footballToken.mintTo(0, 1, user2, address(usdc));

        assertEq(footballToken.balanceOf(user), 3);
        assertEq(footballToken.balanceOf(user2), 3);
        assertEq(footballToken.ownerOf(0), user);
        assertEq(footballToken.ownerOf(1), user2);
        assertEq(footballToken.ownerOf(2), user);
        assertEq(footballToken.ownerOf(3), user2);
        assertEq(footballToken.ownerOf(4), user);
        assertEq(footballToken.ownerOf(5), user2);

        assertEq(footballToken.tokenToCollection(0), 0);
        assertEq(footballToken.tokenToCollection(1), 0);
        assertEq(footballToken.tokenToCollection(2), 1);
        assertEq(footballToken.tokenToCollection(3), 1);
        assertEq(footballToken.tokenToCollection(4), 0);
        assertEq(footballToken.tokenToCollection(5), 0);
    }

    function test_mintTo_revert_BeforeStartDate() public {
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
        vm.expectRevert(abi.encodeWithSelector(IFootballTokenV1.MintError.selector, MintErrorReason.MINT_NOT_OPENED));
        footballToken.mintTo(1, 1, user, address(usdc));
    }

    function test_mintTo_revert_AfterCloseDate() public {
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
        vm.expectRevert(abi.encodeWithSelector(IFootballTokenV1.MintError.selector, MintErrorReason.MINT_NOT_OPENED));
        footballToken.mintTo(0, 1, user, address(usdc));
    }

    // Non admin call admin function test
    function test_createCollection_revert_NotAdmin() public {
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(user);
        vm.expectRevert();
        footballToken.createCollection(collection);
    }

    function test_updateCollection_revert_NotAdmin() public {
        // Create collection first as admin
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

        // Try to update as non-admin
        collection.name = "Updated Collection";
        vm.prank(user);
        vm.expectRevert();
        footballToken.updateCollection(1, collection);
    }

    function test_pauseCollection_revert_notAdmin() public {
        // Create collection first as admin
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

        // Try to pause as non-admin
        vm.prank(user);
        vm.expectRevert();
        footballToken.setPauseCollection(1, true);
    }
}
