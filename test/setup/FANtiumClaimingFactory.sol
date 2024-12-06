// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { FANtiumClaimingV2 } from "src/FANtiumClaimingV2.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumNFTFactory } from "test/setup/FANtiumNFTFactory.sol";

contract FANtiumClaimingFactory is BaseTest, FANtiumNFTFactory {
    address public fantiumClaiming_admin;
    address public fantiumClaiming_manager;
    address public fantiumClaiming_trustedForwarder;

    address public fantiumClaiming_implementation;
    address public fantiumClaiming_proxy;
    FANtiumClaimingV2 public fantiumClaiming;

    function setUp() public virtual override {
        FANtiumNFTFactory.setUp();

        fantiumClaiming_implementation = address(new FANtiumClaimingV2());
        fantiumClaiming_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumClaiming_implementation, abi.encodeCall(FANtiumClaimingV2.initialize, (fantiumNFT_admin))
        );
        fantiumClaiming = FANtiumClaimingV2(fantiumClaiming_proxy);

        // Configure roles
        vm.startPrank(fantiumNFT_admin);
        fantiumClaiming.grantRole(fantiumClaiming.MANAGER_ROLE(), fantiumClaiming_manager);
        fantiumClaiming.grantRole(fantiumClaiming.FORWARDER_ROLE(), fantiumClaiming_trustedForwarder);

        // Set FANtiumNFT created in the FANtiumNFTFactory
        fantiumClaiming.setFANtiumNFT(fantiumNFT);
        fantiumClaiming.setGlobalPayoutToken(address(usdc));
        vm.stopPrank();
    }
}
