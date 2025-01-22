// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ERC721AQueryableUpgradeable } from "erc721a-upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IFANtiumToken, Phase } from "./interfaces/IFANtiumToken.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract FANtiumTokenV1 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC721AQueryableUpgradeable,
    OwnableRoles,
    IFANtiumToken
{
    uint256 private nextId;
    Phase[] public phases;
    uint256 public currentPhaseIndex;
    address public treasury; // Safe that will receive all the funds

    /**
     * @notice The ERC20 token used for payments, dollar stable coin.
     */
    address public erc20PaymentToken; // todo: add fn to set erc20PaymentToken

    string private constant NAME = "FANtium Token";
    string private constant SYMBOL = "FAN";

    // errors
    error PhaseDoesNotExist(uint256 phaseIndex);

    function initialize(address admin) public initializerERC721A initializer {
        __UUPSUpgradeable_init();
        __ERC721A_init(NAME, SYMBOL);
        _initializeOwner(admin);
        nextId = 0;
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

    function addPhase(
        uint256 pricePerShare,
        uint256 maxSupply,
        uint256 startTime,
        uint256 endTime
    )
        external
        onlyOwner
    {
        // todo: check how to throw error correctly
        // validate incoming data
        // todo: check that startTime is date in the future
        require(endTime > startTime, "End time must be after start time");
        require(pricePerShare > 0, "Price per token must be greater than zero");
        require(maxSupply > 0, "Max supply must be greater than zero");

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

    function removePhase(uint256 phaseIndex) external onlyOwner {
        // todo: check how to throw error correctly
        // check that phaseIndex is valid
        require(phaseIndex < phases.length, "Invalid phase index");
        // todo: check that phase has not started yet

        // Shift all elements after the index to the left
        for (uint256 i = phaseIndex; i < phases.length - 1; i++) {
            phases[i] = phases[i + 1];
        }
        phases.pop(); // Remove the last element
    }

    // todo: decide if it should be external or internal fn
    function setCurrentPhase(uint256 phaseIndex) external onlyOwner {
        // todo: check how to throw error correctly
        // check that phaseIndex is valid
        require(phaseIndex < phases.length && phaseIndex >= 0, "Invalid phase index");

        currentPhaseIndex = phaseIndex;
    }

    /**
     * Get current sale phase
     */
    function getCurrentPhase() external view returns (Phase memory) {
        // todo: check how to throw error correctly
        // check that there are phases
        require(phases.length > 0, "No phases available");

        return phases[currentPhaseIndex];
    }

    /**
     * Helper to view all existing sale phases
     */
    function getAllPhases() public view returns (Phase[] memory) {
        return phases;
    }

    /**
     * Mint FANtiums to the recipient address.
     * @param recipient The recipient of the FAN tokens (can be different that the sender)
     * @param quantity The quantity of FAN tokens to mint
     *
     * mintTo(0x123, 100) => please mint 100 FAN to 0x123
     */
    function mintTo(address recipient, uint256 quantity) external whenNotPaused {
        // get current phase
        Phase memory phase = phases[currentPhaseIndex];
        // check that phase was found
        if (phase.phaseId == 0 || phase.startTime == 0) {
            revert PhaseDoesNotExist(currentPhaseIndex);
        }

        // todo: check that phase is active
        // todo: check that current supply + quantity <= maxSupply

        // calculate expected amount
        uint256 expectedAmount =
            quantity * phase.pricePerShare * 10 ** IERC20MetadataUpgradeable(erc20PaymentToken).decimals();

        // transfer stable coin from msg.sender to this treasury
        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(erc20PaymentToken), msg.sender, treasury, expectedAmount
        );

        // mint the FAN tokens to the recipient
        _mint(recipient, quantity);

        // todo: change the currentSupply in the Phase
    }

    // todo: implement this - Once the phase n is exhausted, the phase n+1 is automatically opened
}
