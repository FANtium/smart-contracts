// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { UChildERC20 } from "src/vendor/USDCe.sol";

contract DeployUSDCe is Script {
    address public constant ADMIN = 0xF00D14B2bf0b37177b6e13374aB4F34902Eb94fC;

    function run() public {
        vm.startBroadcast(vm.envUint("ADMIN_PRIVATE_KEY"));
        UChildERC20 usdce = new UChildERC20();
        usdce.initialize("USD Coin (PoS)", "USDC", 6, ADMIN);
        vm.stopBroadcast();
    }
}
