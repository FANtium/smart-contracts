// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

contract BaseTest is Test {
    function loadFixture(string memory fixtureName) public view returns (bytes memory) {
        string memory path = string.concat(vm.projectRoot(), "/test/fixtures/", fixtureName);
        bytes memory data = vm.parseJson(vm.readFile(path));
        return data;
    }
}
