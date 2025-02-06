// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Test } from "forge-std/Test.sol";

contract BaseTest is Test {
    using Strings for uint256;

    address public nobody = makeAddr("nobody");

    function loadFixture(string memory fixtureName) public view returns (bytes memory) {
        string memory path = string.concat(vm.projectRoot(), "/test/fixtures/", fixtureName);
        bytes memory data = vm.parseJson(vm.readFile(path));
        return data;
    }

    function expectMissingRole(address account, bytes32 role) internal {
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(uint160(account), 20),
                " is missing role ",
                Strings.toHexString(uint256(role), 32)
            )
        );
    }
}
