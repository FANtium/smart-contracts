// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Collection} from "../../src/interfaces/IFANtiumNFT.sol";
import {FANtiumNFTV5} from "../../src/FANtiumNFTV5.sol";
import {UnsafeUpgrades} from "../../src/upgrades/UnsafeUpgrades.sol";
import {Test} from "forge-std/Test.sol";

contract FANtiumNFTFactory is Test {
    address public admin = makeAddr("admin");
    address public platformManager = makeAddr("platformManager");
    address public upgrader = makeAddr("upgrader");
    address public trustedForwarder = makeAddr("trustedForwarder");
    address payable public athlete = payable(makeAddr("athlete"));
    address payable public treasuryPrimary = payable(makeAddr("treasuryPrimary"));
    address payable public treasurySecondary = payable(makeAddr("treasurySecondary"));

    address public implementation;
    address public proxy;
    FANtiumNFTV5 public instance;

    constructor(IERC20Metadata usdc) {
        implementation = address(new FANtiumNFTV5());
        proxy = UnsafeUpgrades.deployUUPSProxy(
            implementation,
            abi.encodeCall(FANtiumNFTV5.initialize, ("FANtium", "FAN", admin))
        );
        instance = FANtiumNFTV5(proxy);

        // Configure roles
        vm.startPrank(admin);
        instance.grantRole(instance.UPGRADER_ROLE(), upgrader);
        instance.grantRole(instance.PLATFORM_MANAGER_ROLE(), platformManager);
        instance.setTrustedForwarder(trustedForwarder);
        vm.stopPrank();

        // Configure collections
        vm.startPrank(treasuryPrimary);

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/fixtures/collections.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        Collection[] memory collections = abi.decode(data, (Collection[]));

        for (uint256 i = 0; i < collections.length; i++) {
            instance.addCollection(
                collections[i].athleteAddress,
                collections[i].athletePrimarySalesBPS,
                collections[i].athleteSecondarySalesBPS,
                collections[i].maxInvocations,
                collections[i].price,
                collections[i].launchTimestamp,
                collections[i].fantiumSalesAddress,
                collections[i].fantiumSecondarySalesBPS,
                collections[i].tournamentEarningShare1e7,
                collections[i].otherEarningShare1e7
            );
        }
        vm.stopPrank();
    }
}
