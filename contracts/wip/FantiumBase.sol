// SPDX-License-Identifier: Apache 2.0
pragma solidity 0.8.13;

import "../FantiumNFT.sol";

contract FantiumBase is FantiumNFT {
    //add gap to avoid storage overlap with FantiumNFT
    uint256 public newInt; 
    uint256 public anotherNewInt;
    uint256[999] private __gap;
}