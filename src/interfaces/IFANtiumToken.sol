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
interface IFANtiumToken is IERC721AQueryableUpgradeable {
    // events
    event FANtiumTokenSale( uint24 quantity, address indexed recipient, uint256 amount);

    // errors
    error PhaseDoesNotExist(uint256 phaseIndex);
    error CurrentPhaseIsNotActive(Phase phase);
    error NoPhasesAdded();
    error IncorrectStartOrEndTime(uint256 startTime, uint256 endTime);
    error CannotRemovePhaseWhichAlreadyStarted();
    error PreviousAndNextPhaseTimesOverlap();
    error CannotSetEndedPhaseAsCurrentPhase();
    error IncorrectSharePrice(uint256 price);
    error IncorrectMaxSupply(uint256 maxSupply);
    error IncorrectPhaseIndex(uint256 index);
    error IncorrectTokenQuantity(uint256 quantity);
    error QuantityExceedsMaxSupplyLimit(uint256 quantity);
    error MaxSupplyLimitExceeded(uint256 supply);
    error IncorrectSupplyValue(uint256 supply);
    error PhaseWithIdDoesNotExist(uint256 id);
    error IncorrectEndTime(uint256 endTime);
    error IncorrectStartTime(uint256 startTime);
    error ERC20PaymentTokenIsNotSet();
}
