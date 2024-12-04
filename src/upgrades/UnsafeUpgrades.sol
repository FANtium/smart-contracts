// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UnsafeUpgrades as OZUnsafeUpgrades } from "@openzeppelin/foundry-upgrades/LegacyUpgrades.sol";

/**
 * @title UnsafeUpgrades
 * @author Mathieu Bour - FANtium AG
 * @notice UnsafeUpgrades library for deploying and upgrading proxies as OpenZeppelin's Foundry Upgrades plugin does not
 * supports deploying OpenZeppelin v4 contracts.
 */
library UnsafeUpgrades {
    function deployUUPSProxy(address impl, bytes memory initializerData) internal returns (address) {
        return address(new ERC1967Proxy(impl, initializerData));
    }

    function upgradeProxy(address proxy, address newImpl, bytes memory data) internal {
        OZUnsafeUpgrades.upgradeProxy(proxy, newImpl, data);
    }

    function upgradeProxy(address proxy, address newImpl, bytes memory data, address tryCaller) internal {
        OZUnsafeUpgrades.upgradeProxy(proxy, newImpl, data, tryCaller);
    }
}
