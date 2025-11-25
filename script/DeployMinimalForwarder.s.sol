// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { MinimalForwarder } from "@openzeppelin/contracts/metatx/MinimalForwarder.sol";
import { Script, VmSafe } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

contract DeployMinimalForwarder is Script {
    /**
     * @notice Salt for CREATE2 deployment. Change this to get a different address.
     * @dev Use a unique salt per network to ensure different addresses on different chains.
     */
    bytes32 public constant SALT = keccak256("FANtium Minimal Forwarder v2");

    function run() public {
        bytes memory bytecode = type(MinimalForwarder).creationCode;
        address predictedAddress = vm.computeCreate2Address(SALT, keccak256(bytecode));

        console.log("Predicted MinimalForwarder address:", predictedAddress);
        console.log("Deployer address:", msg.sender);

        VmSafe.Chain memory chain = vm.getChain(block.chainid);
        console.log("Chain name:", chain.name);

        vm.createSelectFork(chain.rpcUrl);
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        MinimalForwarder forwarder = new MinimalForwarder{ salt: SALT }();
        vm.stopBroadcast();

        require(address(forwarder) == predictedAddress, "Address mismatch");
        console.log("Deployed MinimalForwarder at:", address(forwarder));
    }
}
