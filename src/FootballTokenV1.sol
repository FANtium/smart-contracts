// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC721AQueryableUpgradeable } from "erc721a-upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { IFootballTokenV1, FootballCollection } from "src/interfaces/IFootballTokenV1.sol";

contract FootballTokenV1 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC721AQueryableUpgradeable,
    OwnableRoles,
    IFootballTokenV1
{
    string private constant NAME = "FANtium Football";
    string private constant SYMBOL = "FANT";

    // collectionId => collection
    mapping(uint256 => FootballCollection) private _collections;
    // tokenId => collectionId
    mapping(uint256 => uint256) private _tokenToCollection;
    // tokens accepted as payment
    mapping(address => bool) private acceptedTokens;

    function initialize(address admin) external initializer {
        __ERC721A_init(NAME, SYMBOL);
        __UUPSUpgradeable_init();
        __Pausable_init();
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

    function tokenCollection(uint256 tokenId) external view returns (FootballCollection memory) { }

    function mintTo(uint256 collectionId, uint256 quantity, address recipient) external {
        _mint(recipient, quantity); // from ERC721A

        // TODO: save collectionId
        // TODO: transfer price in ERC20?
        // accept DAI, USDC.e, USDC, USDT (considered as 1=1USD)
    }

    // setAcceptedTokens([USDC], true) => allow USDC
    // setAcceptedTokens([USDC], false) => disallow USDC
    // setAcceptedTokens([USDC, USDT], true) => allow USDC and USDT
    function setAcceptedTokens(address[] calldata tokens, bool accepted) external onlyOwner { }

    // admin functions to manage collections
    function createCollection(FootballCollection memory collection) external onlyOwner { }

    function updateCollection(uint256 collectionId, FootballCollection memory collection) external onlyOwner { }

    // TODO: pause / unpause collection
}
