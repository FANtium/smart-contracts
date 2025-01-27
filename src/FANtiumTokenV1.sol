// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IFANtiumToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import { ERC721AQueryableUpgradeable } from "erc721a-upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IFANtiumToken, Phase } from "./interfaces/IFANtiumToken.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title FANtium Token (FAN) smart contract
 * @author Alex Chernetsky, Mathieu Bour - FANtium AG
 */
contract FANtiumTokenV1 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC721AQueryableUpgradeable,
    OwnableRoles,
    IFANtiumToken
{
    uint256 private nextId; // has default value 0
    Phase[] public phases;
    uint256 public currentPhaseIndex;
    address public treasury; // Safe that will receive all the funds

    /**
     * @notice The ERC20 tokens used for payments, dollar stable coins (e.g. USDC, USDT, DAI).
     * we count that all dollar stable coins have the same value 1:1
     */
    mapping(address => bool) public erc20PaymentTokens;

    string private constant NAME = "FANtium Token";
    string private constant SYMBOL = "FAN";

    function initialize(address admin) public initializerERC721A initializer {
        __UUPSUpgradeable_init();
        __ERC721A_init(NAME, SYMBOL);
        _initializeOwner(admin);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address) internal view override {
        _checkOwner();
    }

    /**
     * Set treasury address - FANtium address where the funds should be transferred
     * @param wallet - address of the treasury
     */
    function setTreasuryAddress(address wallet) external onlyOwner {
        // Ensure the token address is not zero
        if (wallet == address(0)) {
            revert InvalidTreasuryAddress(wallet);
        }

        // Ensure the treasury address is not the same as the current one
        if (wallet == treasury) {
            revert TreasuryAddressAlreadySet(wallet);
        }

        // update the treasury address
        treasury = wallet;

        // emit an event for transparency
        emit TreasuryAddressUpdate(wallet);
    }

    /**
     * Add payment token
     * @param token - address of the contract to be set as the payment token
     */
    function addPaymentToken(address token) external onlyOwner {
        // Ensure the token address is not zero
        if (token == address(0)) {
            revert InvalidPaymentTokenAddress(token);
        }

        // check if the token implements the ERC20 interface
        if (IERC20(token).totalSupply() == 0) {
            revert InvalidPaymentTokenAddress(token);
        }

        // set the payment token
        erc20PaymentTokens[token] = true;
    }

    /**
     * Delete payment token (remove an entry from the mapping)
     * @param token - address of the contract to be set as the payment token
     */
    function removePaymentToken(address token) external onlyOwner {
        delete erc20PaymentTokens[token];
    }

    /**
     * Add a new sale phase
     * @param pricePerShare Price of a single share
     * @param maxSupply Maximum amount of shares in the sale phase
     * @param startTime Time of the sale start
     * @param endTime Time of the sale end
     */
    function addPhase(
        uint256 pricePerShare,
        uint256 maxSupply,
        uint256 startTime,
        uint256 endTime
    )
        external
        onlyOwner
    {
        // validate incoming data
        if (endTime <= startTime || startTime <= block.timestamp) {
            // End time must be after start time
            // StartTime should be a date in the future
            revert IncorrectStartOrEndTime(startTime, endTime);
        }

        if (pricePerShare == 0) {
            // Price per token must be greater than zero
            revert IncorrectSharePrice(pricePerShare);
        }

        if (maxSupply == 0) {
            // Max supply must be greater than zero
            revert IncorrectMaxSupply(maxSupply);
        }

        // latestPhase will not exist initially
        if (phases.length - 1 >= 0) {
            Phase memory latestPhase = phases[phases.length - 1];
            // check that previous and next phase do not overlap
            if (latestPhase.endTime >= startTime) {
                revert PreviousAndNextPhaseTimesOverlap();
            }
        }

        // add new Phase
        phases.push(
            Phase({
                phaseId: nextId,
                pricePerShare: pricePerShare,
                maxSupply: maxSupply,
                startTime: startTime,
                endTime: endTime,
                currentSupply: 0
            })
        );

        // increment counter
        nextId++;
    }

    /**
     * Remove the existing sale phase
     * @param phaseIndex The index of the sale phase
     */
    // todo: test the removePhase fn extensively, especially the edge cases
    function removePhase(uint256 phaseIndex) external onlyOwner {
        // check that phaseIndex is valid
        if (phaseIndex >= phases.length) {
            revert IncorrectPhaseIndex(phaseIndex);
        }

        Phase memory phaseToRemove = phases[phaseIndex];

        // check that phase has not started yet, we cannot remove phase which already started
        if (phaseToRemove.startTime < block.timestamp) {
            revert CannotRemovePhaseWhichAlreadyStarted();
        }

        // remove the phase from the array, preserve the order of the items
        // shift all elements after the index to the left
        for (uint256 i = phaseIndex; i < phases.length - 1; i++) {
            phases[i] = phases[i + 1];
        }
        phases.pop(); // remove the last element
    }

    /**
     * Set currentPhaseIndex and therefore the current sale phase
     * @param phaseIndex The index of the sale phase
     */
    function setCurrentPhase(uint256 phaseIndex) public onlyOwner {
        // check that phaseIndex is valid
        if (phaseIndex >= phases.length || phaseIndex < 0) {
            revert IncorrectPhaseIndex(phaseIndex);
        }

        // we cannot set past phase as a current phase
        Phase memory phaseToBeSet = phases[phaseIndex];
        if (phaseToBeSet.endTime <= block.timestamp) {
            revert CannotSetEndedPhaseAsCurrentPhase();
        }

        currentPhaseIndex = phaseIndex;
    }

    /**
     * View to see the current sale phase
     */
    function getCurrentPhase() external view returns (Phase memory) {
        // check that there are phases
        if (phases.length == 0) {
            revert NoPhasesAdded();
        }

        return phases[currentPhaseIndex];
    }

    /**
     * Helper to view all existing sale phases
     */
    function getAllPhases() public view returns (Phase[] memory) {
        return phases;
    }

    /**
     * Get phase from an array by phaseId
     * @param id - phase id
     * @return bool true if sale phase is found, false - if not found.
     * @return Phase which was found, or default values - if not found.
     * @return uint256 index of the Phase in an array, 0 - if not found.
     */
    function _findPhaseById(uint256 id) private view returns (bool, Phase memory, uint256) {
        for (uint256 i = 0; i < phases.length; i++) {
            if (phases[i].phaseId == id) {
                return (true, phases[i], i); // Return Phase, index, true if phase is found
            }
        }

        return (false, Phase(0, 0, 0, 0, 0, 0), 0); // Return default values and `false` if not found
    }

    /**
     * Change end time of the specific sale phase
     * @param newEndTime new sale phase end time to be set
     * @param phaseId id of the sale phase
     */
    function changePhaseEndTime(uint256 newEndTime, uint256 phaseId) external onlyOwner {
        (bool isFound, Phase memory phase, uint256 phaseIndex) = _findPhaseById(phaseId);

        // ensure the phase exists
        if (!isFound) {
            revert PhaseWithIdDoesNotExist(phaseId);
        }

        // validate newEndTime
        if (newEndTime <= phase.startTime || block.timestamp > newEndTime) {
            // End time must be after start time
            // End time should be a date in future
            revert IncorrectEndTime(newEndTime);
        }

        // Explicitly check for out-of-bounds access when dealing with nextPhase
        if (phaseIndex + 1 < phases.length) {
            // check that phases do not overlap
            Phase memory nextPhase = phases[phaseIndex + 1];
            if (nextPhase.startTime < newEndTime) {
                revert PreviousAndNextPhaseTimesOverlap();
            }
        }

        // update end time
        phase.endTime = newEndTime;
    }

    /**
     * Change start time of the specific sale phase
     * @param newStartTime new sale phase start time to be set
     * @param phaseId id of the sale phase
     */
    function changePhaseStartTime(uint256 newStartTime, uint256 phaseId) external onlyOwner {
        (bool isFound, Phase memory phase, uint256 phaseIndex) = _findPhaseById(phaseId);

        if (!isFound) {
            revert PhaseWithIdDoesNotExist(phaseId);
        }

        // validate newStartTime
        if (newStartTime > phase.endTime || block.timestamp > newStartTime) {
            // End time must be after start time
            // Start time should be a date in future
            revert IncorrectStartTime(newStartTime);
        }

        // Explicitly check for out-of-bounds access when dealing with previousPhase
        if (phaseIndex - 1 >= 0) {
            // check that phases do not overlap
            Phase memory previousPhase = phases[phaseIndex - 1];
            if (previousPhase.endTime > newStartTime) {
                revert PreviousAndNextPhaseTimesOverlap();
            }
        }

        // change the start time
        phase.startTime = newStartTime;
    }

    /**
     * Change current supply of the active sale phase
     * Internal function, which is only used by the mintTo function
     * @param currentSupply how many tokens has been minted already
     */
    function _changePhaseCurrentSupply(uint256 currentSupply) internal {
        Phase memory currentPhase = phases[currentPhaseIndex];
        // check that currentSupply does not exceed the max limit
        if (currentSupply > currentPhase.maxSupply) {
            revert MaxSupplyLimitExceeded(currentSupply);
        }
        if (currentSupply < currentPhase.currentSupply) {
            // check that currentSupply is bigger than the prev value
            revert IncorrectSupplyValue(currentSupply);
        }

        // change the currentSupply value
        currentPhase.currentSupply = currentSupply;
    }

    /**
     * Change max supply of the sale phase
     * External function, which can be used if business requirements change
     * @param maxSupply - new max supply value
     * @param phaseId - id of the phase to be edited
     */
    function changePhaseMaxSupply(uint256 maxSupply, uint256 phaseId) external onlyOwner {
        (bool isFound, Phase memory phase, uint256 phaseIndex) = _findPhaseById(phaseId);

        // ensure the phase exists
        if (!isFound) {
            revert PhaseWithIdDoesNotExist(phaseId);
        }

        // max supply cannot be 0
        // max supply should be bigger than currentSupply
        if (maxSupply == 0 || maxSupply < phase.currentSupply) {
            revert InvalidMaxSupplyValue(maxSupply);
        }

        // we cannot change the max supply for the ended sale phases
        if (phase.endTime < block.timestamp) {
            revert CannotUpdateEndedSalePhase();
        }

        // update the max supply value
        phase.maxSupply = maxSupply;
    }

    /**
     * Mint FANtiums to the recipient address.
     * @param recipient The recipient of the FAN tokens (can be different that the sender)
     * @param quantity The quantity of FAN tokens to mint
     * @param paymentToken The address of the stable coin
     *
     * mintTo(0x123, 100) => please mint 100 FAN to 0x123
     */
    function mintTo(address recipient, uint256 quantity, address paymentToken) external whenNotPaused {
        // get current phase
        Phase memory phase = phases[currentPhaseIndex];
        // check that phase was found
        if (phase.phaseId == 0 || phase.startTime == 0) {
            revert PhaseDoesNotExist(currentPhaseIndex);
        }
        // check that phase is active
        // should be phase.startTime < block.timestamp < phase.endTime
        if (phase.startTime > block.timestamp || phase.endTime < block.timestamp) {
            revert CurrentPhaseIsNotActive(phase);
        }
        // check quantity
        // no need to check if quantity is negative, because uint256 cannot be negative
        if (quantity == 0) {
            revert IncorrectTokenQuantity(quantity);
        }
        if (phase.currentSupply + quantity > phase.maxSupply) {
            revert QuantityExceedsMaxSupplyLimit(quantity);
        }

        // payment token validation
        if (!erc20PaymentTokens[paymentToken]) {
            revert ERC20PaymentTokenIsNotSet();
        }

        // price calculation
        uint8 tokenDecimals = IERC20MetadataUpgradeable(paymentToken).decimals();
        uint256 expectedAmount = quantity * phase.pricePerShare * 10 ** tokenDecimals;

        // transfer stable coin from msg.sender to this treasury
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(paymentToken), msg.sender, treasury, expectedAmount);

        // mint the FAN tokens to the recipient
        _mint(recipient, quantity);

        // change the currentSupply in the Phase
        _changePhaseCurrentSupply(phase.currentSupply + quantity);

        // if we sold out the tokens at a certain valuation, we need to open the next stage
        // once the phase n is exhausted, the phase n+1 is automatically opened
        if (phase.currentSupply + quantity == phase.maxSupply) {
            // check if there is a phase with index = currentPhaseIndex + 1
            Phase memory nextPhase = phases[currentPhaseIndex + 1];
            if (nextPhase.pricePerShare != 0 && nextPhase.maxSupply != 0) {
                setCurrentPhase(currentPhaseIndex + 1);
            }
        }

        // emit an event after minting tokens
        emit FANtiumTokenSale(quantity, recipient, expectedAmount);
    }
}
