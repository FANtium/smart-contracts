// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC721AQueryableUpgradeable } from "erc721a-upgradeable/interfaces/IERC721AQueryableUpgradeable.sol";

struct Phase {
    uint256 phaseId;
    uint256 pricePerShare;
    uint256 maxSupply; // total number of shares
    uint256 currentSupply; // number of minted shares for the phase (<= maxSupply)
    uint256 startTime;
    uint256 endTime;
}

// A phase has a certain number of NFTs available at a certain price
// Once the phase n is exhausted, the phase n+1 is automatically opened
// The price per share of phase n is < the price per share at the phase n+1
// When the last phase is exhausted, it’s not possible to purchase any further share
interface IFANtiumToken is IERC721AQueryableUpgradeable { }
