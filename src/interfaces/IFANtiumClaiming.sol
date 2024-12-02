// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IFANtiumClaiming {
    function claim(address to, uint256 amount) external;
}
