// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC721AQueryableUpgradeable } from "erc721a-upgradeable/interfaces/IERC721AQueryableUpgradeable.sol";

// TODO: open / close dates
// TODO: isPaused
struct FootballCollection {
    string name;
    uint256 priceUSD; // in USD (decimals = 0)
    uint256 supply; // current number of tokens of this collection in circulation
    uint256 maxSupply; // max number of tokens of this collection
}

struct UpdateFootballCollection {
    string name;
    uint256 priceUSD; // in USD (decimals = 0)
    uint256 maxSupply; // max number of tokens of this collection}
}

interface IFootballTokenV1 is IERC721AQueryableUpgradeable { }
