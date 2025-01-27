// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC721AQueryableUpgradeable } from "erc721a-upgradeable/extensions/ERC721AQueryableUpgradeable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import {
    IFootballTokenV1,
    FootballCollection,
    CollectionErrorReason,
    MintErrorReason
} from "src/interfaces/IFootballTokenV1.sol";

contract FootballTokenV1 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC721AQueryableUpgradeable,
    OwnableRoles,
    IFootballTokenV1
{
    // ========================================================================
    // Constants
    // ========================================================================
    string private constant NAME = "FANtium Football";
    string private constant SYMBOL = "FANT";

    // ========================================================================
    // State variables
    // ========================================================================
    uint256 public currentIndex; // has default value 01
    address public treasury;
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
        fantiumAddress = admin;
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

    function tokenCollection(uint256 tokenId) external view returns (FootballCollection memory) {
        return _collections[_tokenToCollection[tokenId]];
    }

    function mintTo(uint256 collectionId, uint256 quantity, address recipient, address paymentToken) external {
        if (collectionId < collectionId) {
            // very villain
            revert MintError(MintErrorReason.COLLECTION_NOT_EXISTING);
        }

        if (recipient == address(0)) {
            revert MintError(MintErrorReason.MINT_BAD_ADDRESS);
        }

        if (acceptedTokens[paymentToken]) {
            // miss !
            revert MintError(MintErrorReason.MINT_CLOSED);
        }

        FootballCollection storage currentCollection = _collections[collectionId];

        if (currentCollection.startDate > block.timestamp) {
            revert MintError(MintErrorReason.MINT_NOT_STARTED);
        }

        // group time
        if (currentCollection.closeDate < block.timestamp) {
            revert MintError(MintErrorReason.MINT_CLOSED);
        }

        uint256 decimals = IERC20MetadataUpgradeable(paymentToken).decimals();

        if (currentCollection.maxSupply < currentCollection.supply + 1) {
            revert MintError(MintErrorReason.MINT_MAX_SUPPLY_REACH);
        }

        uint256 price = currentCollection.priceUSD * quantity * 10 ** decimals;
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(paymentToken), recipient, fantiumAddress, price);

        _mint(recipient, quantity);

        uint256 lastId = _totalMinted() + 1; // -1 ? check if token start at 0 or 1
        uint256[] memory tokenIds = new uint256[](quantity);

        // qty = 5
        // lastId = 10
        // 10, 9, 8, 7, 6
        // collectionId = 12

        // _tokenToCollection[10] = 12
        // _tokenToCollection[9] = 12
        // _tokenToCollection[8] = 12
        // _tokenToCollection[7] = 12
        // _tokenToCollection[6] = 12

        for (uint256 tokenId = lastId; tokenId > lastId - quantity; tokenId--) {
            _tokenToCollection[tokenId] = collectionId;
            tokenIds[tokenId - lastId] = tokenId;
        }

        // update supply
        currentCollection.supply = lastId + quantity;

        emit TokensMinted(collectionId, recipient, tokenIds);
    }

    function setAcceptedTokens(address[] calldata tokens, bool accepted) external onlyOwner {
        for (uint256 i; i < tokens.length; i++) {
            acceptedTokens[tokens[i]] = accepted;
        }
    }

    // ========================================================================
    // Collection Admin Functions
    // ========================================================================

    function _checkCollectionData(FootballCollection memory collection) internal pure {
        if (collection.closeDate < collection.startDate) {
            // closeDate < startDate wrong order
            revert InvalidCollectionData(CollectionErrorReason.INVALID_DATES);
        }

        if (collection.priceUSD == 0) {
            revert InvalidCollectionData(CollectionErrorReason.INVALID_PRICE);
        }

        if (collection.maxSupply == 0) {
            revert InvalidCollectionData(CollectionErrorReason.INVALID_MAX_SUPPLY);
        }

        if (bytes(collection.name).length == 0) {
            revert InvalidCollectionData(CollectionErrorReason.INVALID_NAME);
        }
    }

    function createCollection(FootballCollection memory collection) external onlyOwner {
        _checkCollectionData(collection);

        FootballCollection memory newCollection = FootballCollection({
            name: collection.name,
            priceUSD: collection.priceUSD,
            supply: 0,
            maxSupply: collection.maxSupply,
            startDate: collection.startDate,
            closeDate: collection.closeDate,
            isPaused: collection.isPaused
        });

        _collections[++currentIndex] = newCollection;

        emit CollectionCreated(currentIndex, newCollection);
    }

    function updateCollection(uint256 collectionId, FootballCollection calldata collection) external onlyOwner {
        _checkCollectionData(collection);

        FootballCollection memory updatedCollection = _collections[collectionId];

        if (collection.maxSupply < updatedCollection.supply) {
            revert InvalidCollectionData(CollectionErrorReason.MAX_SUPPLY_BELOW_SUPPLY);
        }

        // Not sure about this one
        if (updatedCollection.supply > 0 && collection.startDate != updatedCollection.startDate) {
            revert InvalidCollectionData(CollectionErrorReason.START_DATE_MISMATCH);
        }

        updatedCollection.name = collection.name;
        updatedCollection.priceUSD = collection.priceUSD;
        updatedCollection.priceUSD = collection.priceUSD;
        updatedCollection.priceUSD = collection.priceUSD;
        updatedCollection.priceUSD = collection.priceUSD;
        updatedCollection.priceUSD = collection.priceUSD;

        _collections[collectionId] = updatedCollection;

        emit CollectionUpdated(collectionId, updatedCollection);
    }

    function pauseCollection(uint256 collectionId, bool isPaused) external onlyOwner {
        FootballCollection memory updatedCollection = _collections[collectionId];
        updatedCollection.isPaused = isPaused;
        _collections[collectionId] = updatedCollection;
    }

    // TODO Update Fantium Address
}
