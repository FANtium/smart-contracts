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
    FootballCollectionData,
    CollectionErrorReason,
    MintErrorReason
} from "src/interfaces/IFootballTokenV1.sol";

/**
 * @title Footbal Token V1 smart contract
 * @author Sylvain Coulomb, Mathieu Bour - FANtium AG
 */
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

    // Roles
    // ========================================================================
    uint256 public constant SIGNER_ROLE = _ROLE_0;

    // ========================================================================
    // State variables
    // ========================================================================
    /*
        Used to keep track of number of collection.
     */
    uint256 public nextCollectionIndex; // has default value 0
    address public treasury;

    // collectionId => collection
    mapping(uint256 => FootballCollection) public collections;
    // tokenId => collectionId
    mapping(uint256 => uint256) public tokenToCollection;

    /**
     * @notice The ERC20 token used for payments, dollar stable coin.
     */
    mapping(address => bool) private acceptedTokens;

    /**
     * @notice Initializes the contract with an admin address
     * @param admin The address that will be set as owner and initial treasury
     */
    function initialize(address admin) external initializerERC721A initializer {
        __ERC721A_init(NAME, SYMBOL);
        __UUPSUpgradeable_init();
        __Pausable_init();
        _initializeOwner(admin);
        treasury = admin;
    }

    /**
     * @notice Implementation of the upgrade authorization logic
     * @dev Restricted to the owner
     */
    function _authorizeUpgrade(address) internal view override {
        _checkOwner();
    }

    // ========================================================================
    // Pause
    // ========================================================================
    /**
     * @notice Update contract pause status to `_paused`.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ========================================================================
    // ERC2771
    // ========================================================================
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return hasAllRoles(forwarder, SIGNER_ROLE);
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgSenderERC721A() internal view virtual override returns (address) {
        return _msgSender();
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    // ========================================================================
    // Setters
    // ========================================================================
    /**
     * @notice Sets which ERC20 tokens are accepted for payment
     * @param tokens Array of token addresses to update
     * @param accepted Whether the tokens should be accepted or not
     */
    function setAcceptedTokens(address[] calldata tokens, bool accepted) external onlyOwner {
        for (uint256 i; i < tokens.length; i++) {
            acceptedTokens[tokens[i]] = accepted;
        }
    }

    /**
     * @notice Updates the treasury address that receives payments
     * @param newTreasury The new treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        address oldAddress = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldAddress, newTreasury);
    }

    /**
     * @notice Gets the collection data for a specific token
     * @param tokenId The ID of the token to query
     * @return The FootballCollection data associated with the token
     */
    function tokenCollection(uint256 tokenId) external view returns (FootballCollection memory) {
        return collections[tokenToCollection[tokenId]];
    }

    /**
     * @notice Mints new tokens from a collection to a recipient address
     * @param collectionId The ID of the collection to mint from
     * @param quantity The number of tokens to mint
     * @param recipient The address that will receive the minted tokens
     * @param paymentToken The ERC20 token address used for payment
     */
    function mintTo(uint256 collectionId, uint256 quantity, address recipient, address paymentToken) external {
        if ((collectionId > nextCollectionIndex)) {
            revert MintError(MintErrorReason.COLLECTION_NOT_EXISTING);
        }
        if (quantity == 0) {
            revert MintError(MintErrorReason.MINT_ZERO_QUANTITY);
        }

        if (recipient == address(0)) {
            revert MintError(MintErrorReason.MINT_BAD_ADDRESS);
        }

        if (!acceptedTokens[paymentToken]) {
            revert MintError(MintErrorReason.MINT_ERC20_NOT_ACCEPTED);
        }

        FootballCollection storage currentCollection = collections[collectionId];

        if (block.timestamp < currentCollection.startDate || block.timestamp > currentCollection.closeDate) {
            revert MintError(MintErrorReason.MINT_NOT_OPENED);
        }

        uint256 decimals = IERC20MetadataUpgradeable(paymentToken).decimals();

        if (currentCollection.maxSupply < currentCollection.supply + quantity) {
            revert MintError(MintErrorReason.MINT_MAX_SUPPLY_REACH);
        }

        uint256 price = currentCollection.priceUSD * quantity * 10 ** decimals;
        uint256 lastId = _totalMinted(); // start at  0;

        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(paymentToken), _msgSender(), treasury, price);
        _mint(recipient, quantity);

        uint256[] memory tokenIds = new uint256[](quantity);
        uint256 i = 0;

        for (uint256 tokenId = lastId; tokenId < lastId + quantity; tokenId++) {
            tokenToCollection[tokenId] = collectionId;
            tokenIds[i++] = tokenId;
        }

        currentCollection.supply = lastId + quantity;

        emit TokensMinted(collectionId, recipient, tokenIds);
    }

    // ========================================================================
    // Collection Admin Functions
    // ========================================================================
    function _checkCollectionData(FootballCollectionData memory collection) internal pure {
        if (collection.closeDate < collection.startDate) {
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

    /**
     * @notice Creates a new football collection
     * @param collection The data to create the new football collection
     */
    function createCollection(FootballCollectionData memory collection) external onlyOwner {
        _checkCollectionData(collection);

        FootballCollection memory newCollection = FootballCollection({
            name: collection.name,
            priceUSD: collection.priceUSD,
            supply: 0,
            maxSupply: collection.maxSupply,
            startDate: collection.startDate,
            closeDate: collection.closeDate,
            isPaused: collection.isPaused,
            team: collection.team
        });

        collections[nextCollectionIndex++] = newCollection;

        emit CollectionCreated(nextCollectionIndex, newCollection);
    }

    /**
     * @notice Updates an existing collection's data.
     * @notice You can't update the dates if mint as started
     * @param collectionId The ID of the collection to update
     * @param collection The new collection data
     */
    function updateCollection(uint256 collectionId, FootballCollectionData calldata collection) external onlyOwner {
        _checkCollectionData(collection);

        FootballCollection memory updatedCollection = collections[collectionId];

        if (collection.maxSupply < updatedCollection.supply) {
            revert InvalidCollectionData(CollectionErrorReason.MAX_SUPPLY_BELOW_SUPPLY);
        }

        if (updatedCollection.supply > 0 && collection.startDate != updatedCollection.startDate) {
            revert InvalidCollectionData(CollectionErrorReason.START_DATE_MISMATCH);
        }

        updatedCollection.name = collection.name;
        updatedCollection.priceUSD = collection.priceUSD;
        updatedCollection.maxSupply = collection.maxSupply;
        updatedCollection.startDate = collection.startDate;
        updatedCollection.closeDate = collection.closeDate;
        updatedCollection.isPaused = collection.isPaused;
        updatedCollection.team = collection.team;

        collections[collectionId] = updatedCollection;

        emit CollectionUpdated(collectionId, updatedCollection);
    }

    /**
     * @notice Pauses or unpauses a specific collection
     * @param collectionId The ID of the collection to update
     * @param isPaused The new pause state
     */
    function setPauseCollection(uint256 collectionId, bool isPaused) external onlyOwner {
        FootballCollection storage updatedCollection = collections[collectionId];
        updatedCollection.isPaused = isPaused;
        emit CollectionPausedUpdate(collectionId, isPaused);
    }
}
