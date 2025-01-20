// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ERC721AQueryableUpgradeable } from "erc721a-upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IFANtiumToken } from "./interfaces/IFANtiumToken.sol";

contract FANtiumTokenV1 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC721AQueryableUpgradeable,
    OwnableRoles,
    IFANtiumToken
{
    uint256 public constant PRICE_PER_TOKEN = 100; // USDC
    address public treasury; // Safe that will receive all the funds

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
     * Mint FANtiums to the recipient address.
     * @param recipient The recipient of the FAN tokens (can be defifferent that the sender)
     * @param quantity The quantity of FAN tokens to mint
     *
     * mintTo(0x123, 100) => please mint 100 FAN to 0x123
     */
    function mintTo(address recipient, uint256 quantity) external {
        // 1. transfer USDC from msg.sender to this treasury
        // 2. mint the FAN tokens to the recipient

        /*
        const expectedAmount = quantity * PRICE_PER_TOKEN * 10**USDC_DECIMALS;
        usdc.transferFrom(msg.sender, treasury, expectedAmount); // this might throw
        this.mint(recipient, quantity);
        */
    }
}
