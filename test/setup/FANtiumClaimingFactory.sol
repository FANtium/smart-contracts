// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { FANtiumClaimingV4 } from "src/FANtiumClaimingV4.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumAthletesFactory } from "test/setup/FANtiumAthletesFactory.sol";

contract FANtiumClaimingFactory is BaseTest, FANtiumAthletesFactory {
    address public fantiumClaiming_admin = makeAddr("fantiumClaiming_admin");
    address public fantiumClaiming_manager = makeAddr("fantiumClaiming_manager");
    address public fantiumClaiming_trustedForwarder = makeAddr("fantiumClaiming_trustedForwarder");

    address public fantiumClaiming_implementation;
    address public fantiumClaiming_proxy;
    FANtiumClaimingV4 public fantiumClaiming;

    function setUp() public virtual override {
        FANtiumAthletesFactory.setUp();

        fantiumClaiming_implementation = address(new FANtiumClaimingV4());
        fantiumClaiming_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumClaiming_implementation, abi.encodeCall(FANtiumClaimingV4.initialize, (fantiumClaiming_admin))
        );
        fantiumClaiming = FANtiumClaimingV4(fantiumClaiming_proxy);

        // Configure roles
        vm.startPrank(fantiumClaiming_admin);
        fantiumClaiming.grantRole(fantiumClaiming.MANAGER_ROLE(), fantiumClaiming_manager);
        fantiumClaiming.grantRole(fantiumClaiming.FORWARDER_ROLE(), fantiumClaiming_trustedForwarder);

        // Set FANtiumNFT created in the FANtiumAthletesFactory
        fantiumClaiming.setFANtiumNFT(fantiumAthletes);
        fantiumClaiming.setUserManager(userManager);
        fantiumClaiming.setGlobalPayoutToken(address(usdc));
        vm.stopPrank();
    }
}
