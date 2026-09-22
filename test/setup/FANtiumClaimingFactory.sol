// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { FANtiumClaimingV6 } from "src/FANtiumClaimingV6.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumAthletesFactory } from "test/setup/FANtiumAthletesFactory.sol";

contract FANtiumClaimingFactory is BaseTest, FANtiumAthletesFactory {
    address public fantiumClaiming_admin = makeAddr("fantiumClaiming_admin");
    address public fantiumClaiming_treasury = makeAddr("fantiumClaiming_treasury");
    address public fantiumClaiming_trustedForwarder = makeAddr("fantiumClaiming_trustedForwarder");

    address public fantiumClaiming_implementation;
    address public fantiumClaiming_proxy;
    FANtiumClaimingV6 public fantiumClaiming;

    function setUp() public virtual override {
        FANtiumAthletesFactory.setUp();

        fantiumClaiming_implementation = address(new FANtiumClaimingV6());
        fantiumClaiming_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumClaiming_implementation, abi.encodeCall(FANtiumClaimingV6.initialize, (fantiumClaiming_admin))
        );
        fantiumClaiming = FANtiumClaimingV6(fantiumClaiming_proxy);

        // Configure roles
        vm.startPrank(fantiumClaiming_admin);
        fantiumClaiming.grantRole(fantiumClaiming.FORWARDER_ROLE(), fantiumClaiming_trustedForwarder);

        // Set FANtiumNFT created in the FANtiumAthletesFactory
        fantiumClaiming.setFANtiumNFT(fantiumAthletes);
        fantiumClaiming.setGlobalPayoutToken(address(usdc));
        fantiumClaiming.setTreasury(fantiumClaiming_treasury);
        vm.stopPrank();
    }
}
