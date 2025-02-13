// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { FootballTokenV1 } from "src/FootballTokenV1.sol";
import {
    CollectionErrorReason,
    FootballCollectionData,
    IFootballTokenV1,
    MintErrorReason
} from "src/interfaces/IFootballTokenV1.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "test/BaseTest.sol";

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
        football_proxy =
            UnsafeUpgrades.deployUUPSProxy(football_implementation, abi.encodeCall(FootballTokenV1.initialize, (admin)));
        footballToken = FootballTokenV1(football_proxy);

        usdc = new MockUSDC();
        erc20 = new MockERC20();

        address[] memory tokens = new address[](1);
        tokens[0] = address(usdc);
        vm.prank(admin);
        footballToken.setAcceptedTokens(tokens, true);

        usdc.transfer(user, 10_000 * 10 ** 6);
        erc20.transfer(user, 10_000 * 10 ** 18);
        usdc.transfer(user2, 10_000 * 10 ** 6);
    }
}

contract FootballTokenV1Test is FootballTokenV1Setup {
    // initialize
    // ========================================================================
    function test_initialize_ok() public view {
        assertEq(footballToken.owner(), admin);
        assertEq(footballToken.treasury(), admin);
        assertEq(footballToken.name(), "FANtium Football");
        assertEq(footballToken.symbol(), "FANT");
    }

    // TODO: test_initialize_revert_alreadyInitialized

    // pause
    // ========================================================================
    function test_pause_unpause_ok() public {
        vm.prank(admin);
        footballToken.pause();
        assertTrue(footballToken.paused());

        vm.prank(admin);
        footballToken.unpause();
        assertFalse(footballToken.paused());
    }

    // TODO: test_pause_revert_notOwner
    // TODO: test_unpause_revert_notOwner
    // TODO: test_pause_revert_alreadyPaused
    // TODO: test_unpause_revert_notPaused

    // setAcceptedTokens
    // ========================================================================
    function test_setAcceptedTokens_ok() public {
        address[] memory tokens = new address[](2);
        tokens[0] = address(usdc);
        tokens[1] = address(erc20);

        vm.prank(admin);
        footballToken.setAcceptedTokens(tokens, true);

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

    // TODO: test_setAcceptedTokens_revert_notOwner
    // TODO: test_setAcceptedTokens_revert_zeroAddress

    // setTreasury
    // ========================================================================
    function test_setTreasury_ok() public {
        address newTreasury = makeAddr("newTreasury");

        vm.prank(admin);
        footballToken.setTreasury(newTreasury);

        assertEq(footballToken.treasury(), newTreasury);
    }

    function test_setTreasury_revert_notAdmin() public {
        address newTreasury = makeAddr("newTreasury");

        vm.prank(user);
        vm.expectRevert();
        footballToken.setTreasury(newTreasury);
    }

    // TODO: test_setTreasury_revert_zeroAddress

    // createCollection
    // ========================================================================
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

    function test_createCollection_revert_invalidDates() public {
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp + 7 days,
            closeDate: block.timestamp + 1 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IFootballTokenV1.InvalidCollectionData.selector, CollectionErrorReason.INVALID_DATES)
        );
        footballToken.createCollection(collection);
    }

    function test_createCollection_revert_invalidPrice() public {
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 0,
            maxSupply: 100,
            startDate: block.timestamp,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IFootballTokenV1.InvalidCollectionData.selector, CollectionErrorReason.INVALID_PRICE)
        );
        footballToken.createCollection(collection);
    }

    function test_createCollection_revert_invalidMaxSupply() public {
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 0,
            startDate: block.timestamp,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(
                IFootballTokenV1.InvalidCollectionData.selector, CollectionErrorReason.INVALID_MAX_SUPPLY
            )
        );
        footballToken.createCollection(collection);
    }

    function test_createCollection_revert_invalidName() public {
        FootballCollectionData memory collection = FootballCollectionData({
            name: "",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(IFootballTokenV1.InvalidCollectionData.selector, CollectionErrorReason.INVALID_NAME)
        );
        footballToken.createCollection(collection);
    }

    function test_createCollection_revert_notAdmin() public {
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

    function test_updateCollection_ok() public {
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

    function test_updateCollection_revert_notAdmin() public {
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

        collection.name = "Updated Collection";
        vm.prank(user);
        vm.expectRevert();
        footballToken.updateCollection(1, collection);
    }

    // TODO: test_updateCollection_revert_nonexistentCollection
    // TODO: test_updateCollection_revert_whenPaused
    // TODO: test_updateCollection_revert_startDateAfterMinting

    // setPauseCollection
    // ========================================================================
    function test_setPauseCollection_ok() public {
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

        vm.prank(admin);
        footballToken.setPauseCollection(1, true);

        (,,,,,, bool isPaused,) = footballToken.collections(1);
        assertTrue(isPaused);

        vm.prank(admin);
        footballToken.setPauseCollection(1, false);

        (,,,,,, bool isPausedUpdated,) = footballToken.collections(1);
        assertFalse(isPausedUpdated);
    }

    function test_pauseCollection_revert_notAdmin() public {
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

        vm.prank(user);
        vm.expectRevert();
        footballToken.setPauseCollection(1, true);
    }

    // TODO: test_setPauseCollection_revert_nonexistentCollection
    // TODO: test_setPauseCollection_revert_whenContractPaused
    // TODO: test_setPauseCollection_revert_alreadyInRequestedState

    // mintTo
    // ========================================================================
    function test_mintTo_ok() public {
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

        vm.warp(block.timestamp + 1 days);

        footballToken.mintTo(0, 1, user, address(usdc));
        vm.stopPrank();

        assertEq(footballToken.balanceOf(user), 1);
        assertEq(footballToken.ownerOf(0), user);
    }

    function test_mintTo_ok_multiple() public {
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

        vm.startPrank(user);
        usdc.approve(address(footballToken), type(uint256).max);

        vm.warp(block.timestamp + 1 days);

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

        vm.prank(user);
        usdc.approve(address(footballToken), type(uint256).max);
        vm.prank(user2);
        usdc.approve(address(footballToken), type(uint256).max);

        vm.warp(block.timestamp + 1 days);

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
        FootballCollectionData memory collection1 = FootballCollectionData({
            name: "Test Collection 1",
            priceUSD: 100,
            maxSupply: 100,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        FootballCollectionData memory collection2 = FootballCollectionData({
            name: "Test Collection 2",
            priceUSD: 200,
            maxSupply: 50,
            startDate: block.timestamp + 1 days,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.startPrank(admin);
        footballToken.createCollection(collection1);
        footballToken.createCollection(collection2);
        vm.stopPrank();

        (string memory name,,,,,,,) = footballToken.collections(0);
        (string memory name2,,,,,,,) = footballToken.collections(1);

        assertEq(name, "Test Collection 1");
        assertEq(name2, "Test Collection 2");

        vm.prank(user);
        usdc.approve(address(footballToken), type(uint256).max);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user);
        footballToken.mintTo(0, 1, user, address(usdc));
        footballToken.mintTo(1, 1, user, address(usdc));
        vm.stopPrank();

        assertEq(footballToken.balanceOf(user), 2);
        assertEq(footballToken.ownerOf(0), user);
        assertEq(footballToken.ownerOf(1), user);

        assertEq(footballToken.tokenToCollection(0), 0);
        assertEq(footballToken.tokenToCollection(1), 1);
    }

    function test_mintTo_ok_multiplePeopleAndCollection() public {
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

        vm.prank(user);
        usdc.approve(address(footballToken), type(uint256).max);
        vm.prank(user2);
        usdc.approve(address(footballToken), type(uint256).max);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user);
        footballToken.mintTo(0, 1, user, address(usdc));
        vm.prank(user2);
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

    function test_mintTo_revert_beforeStartDate() public {
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

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IFootballTokenV1.MintError.selector, MintErrorReason.MINT_NOT_OPENED));
        footballToken.mintTo(1, 1, user, address(usdc));
    }

    function test_mintTo_revert_afterCloseDate() public {
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

        vm.warp(block.timestamp + 8 days);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IFootballTokenV1.MintError.selector, MintErrorReason.MINT_NOT_OPENED));
        footballToken.mintTo(0, 1, user, address(usdc));
    }

    function test_mintTo_revert_maxSupplyReached() public {
        FootballCollectionData memory collection = FootballCollectionData({
            name: "Test Collection",
            priceUSD: 100,
            maxSupply: 2,
            startDate: block.timestamp,
            closeDate: block.timestamp + 7 days,
            isPaused: false,
            team: team
        });

        vm.prank(admin);
        footballToken.createCollection(collection);

        vm.startPrank(user);
        usdc.approve(address(footballToken), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(IFootballTokenV1.MintError.selector, MintErrorReason.MINT_MAX_SUPPLY_REACH)
        );
        footballToken.mintTo(0, 3, user, address(usdc));
        vm.stopPrank();
    }

    function test_mintTo_revert_unacceptedToken() public {
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
        erc20.approve(address(footballToken), type(uint256).max);

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(IFootballTokenV1.MintError.selector, MintErrorReason.MINT_ERC20_NOT_ACCEPTED)
        );
        footballToken.mintTo(0, 1, user, address(erc20));
        vm.stopPrank();
    }

    function test_mintTo_revert_collectionNotExisting() public {
        vm.startPrank(user);
        usdc.approve(address(footballToken), type(uint256).max);

        vm.expectRevert(
            abi.encodeWithSelector(IFootballTokenV1.MintError.selector, MintErrorReason.COLLECTION_NOT_EXISTING)
        );
        footballToken.mintTo(1, 1, user, address(usdc));
        vm.stopPrank();
    }

    function test_mintTo_revert_zeroQuantity() public {
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

        vm.expectRevert(abi.encodeWithSelector(IFootballTokenV1.MintError.selector, MintErrorReason.MINT_ZERO_QUANTITY));
        footballToken.mintTo(0, 0, user, address(usdc));
        vm.stopPrank();
    }

    function test_mintTo_revert_zeroAddress() public {
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

        vm.expectRevert(abi.encodeWithSelector(IFootballTokenV1.MintError.selector, MintErrorReason.MINT_BAD_ADDRESS));
        footballToken.mintTo(0, 1, address(0), address(usdc));
        vm.stopPrank();
    }

    // TODO: test_mintTo_revert_whenContractPaused
    // TODO: test_mintTo_revert_whenCollectionPaused
    // TODO: test_mintTo_revert_insufficientAllowance
    // TODO: test_mintTo_revert_insufficientBalance

    // tokenCollection
    // ========================================================================
    // TODO: test_tokenCollection_ok
    // TODO: test_tokenCollection_revert_nonexistentToken

    // batchTransferFrom
    // ========================================================================
    // TODO: test_batchTransferFrom_ok
    // TODO: test_batchTransferFrom_revert_whenPaused
    // TODO: test_batchTransferFrom_revert_notOwnerOrApproved
    // TODO: test_batchTransferFrom_revert_toZeroAddress

    // batchSafeTransferFrom
    // ========================================================================
    // TODO: test_batchSafeTransferFrom_ok
    // TODO: test_batchSafeTransferFrom_revert_whenPaused
    // TODO: test_batchSafeTransferFrom_revert_notOwnerOrApproved
    // TODO: test_batchSafeTransferFrom_revert_toZeroAddress
}
