// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ERC721AQueryableUpgradeable } from "erc721a-upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IFANtiumToken } from "./interfaces/IFANtiumToken.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract FANtiumTokenV1 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC721AQueryableUpgradeable,
    OwnableRoles,
    IFANtiumToken
{
    uint256 public constant PRICE_PER_TOKEN = 100; // USDC, todo: we'll remove hardcoded price later
    address public treasury; // Safe that will receive all the funds

    /**
     * @notice The ERC20 token used for payments, dollar stable coin.
     */
    address public erc20PaymentToken; // todo: add fn to set erc20PaymentToken

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
    function mintTo(address recipient, uint256 quantity) external whenNotPaused {
        // calculate expected amount
        uint256 expectedAmount =
            quantity * PRICE_PER_TOKEN * 10 ** IERC20MetadataUpgradeable(erc20PaymentToken).decimals();

        // transfer stable coin from msg.sender to this treasury
        SafeERC20Upgradeable.safeTransferFrom(
            IERC20Upgradeable(erc20PaymentToken), msg.sender, treasury, expectedAmount
        );

        // mint the FAN tokens to the recipient
        _mint(recipient, quantity);

        // todo: remove the comments below
        /*
        const expectedAmount = quantity * PRICE_PER_TOKEN * 10**USDC_DECIMALS;
        usdc.transferFrom(msg.sender, treasury, expectedAmount); // this might throw
        this.mint(recipient, quantity);
        */
    }
}
