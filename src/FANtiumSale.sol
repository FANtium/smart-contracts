// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Collection, IFANtiumNFT} from "./interfaces/IFANtiumNFT.sol";
import {ERC2771ContextUpgradeable} from "./utils/ERC2771ContextUpgradeable.sol";

struct Purchase {
    uint256 collectionId;
    uint24 quantity;
    uint256 amount;
}

contract FANtiumSale is Initializable, UUPSUpgradeable, AccessControlUpgradeable, ERC2771ContextUpgradeable {
    using ECDSA for bytes32;

    /// @notice The number of decimals to price the tokens.
    uint256 public constant BASE_DECIMALS = 18;

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER");

    error InvalidSignature();
    error InvalidToken(address token);

    // --- begin state ---
    IFANtiumNFT public fantiumNFT;
    mapping(address => bool) public acceptedTokens;
    // --- end state ---

    function initialize(
        IFANtiumNFT _fantiumNFT,
        address _defaultAdmin,
        address[] memory _trustedForwarders
    ) public initializer {
        __AccessControl_init();
        fantiumNFT = _fantiumNFT;

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(UPGRADER_ROLE, _defaultAdmin);
        for (uint256 i = 0; i < _trustedForwarders.length; i++) {
            _grantTrustedForwarder(_trustedForwarders[i]);
        }
    }

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // --- ERC2771 start ---
    function grantTrustedForwarder(address forwarder) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        super._grantTrustedForwarder(forwarder);
    }

    function revokeTrustedForwarder(address forwarder) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        super._revokeTrustedForwarder(forwarder);
    }

    function isTrustedForwarder(
        address forwarder
    ) public view virtual override(ERC2771ContextUpgradeable) returns (bool) {
        return ERC2771ContextUpgradeable.isTrustedForwarder(forwarder);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }
    // --- ERC2771 end ---

    function toggleToken(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        acceptedTokens[token] = !acceptedTokens[token];
    }

    function _purchase(
        uint256 collectionId,
        uint24 quantity,
        address token,
        uint256 amount,
        address recipient
    ) internal {
        // At this point, purchase data can be trusted.
        if (!acceptedTokens[token]) {
            revert InvalidToken(token);
        }

        // Send funds to the treasury and athlete account.
        (uint256 fee, address payable treasury, uint256 athleteAmount, address payable athleteAccount) = fantiumNFT
            .getPrimaryRevenueSplits(collectionId, amount);

        if (fee > 0) {
            IERC20(token).transferFrom(_msgSender(), treasury, fee);
        }

        if (athleteAmount > 0) {
            IERC20(token).transferFrom(_msgSender(), athleteAccount, athleteAmount);
        }

        // Finally, mint the NFTs to the recipient.
        fantiumNFT.mintTo(collectionId, quantity, recipient);
    }

    /**
     * @notice Purchase NFTs from the sale.
     * @param collectionId The collection ID to purchase from.
     * @param quantity The quantity of NFTs to purchase.
     * @param token The token to purchase the NFTs with.
     * @param recipient The recipient of the NFTs.
     */
    function purchase(uint256 collectionId, uint24 quantity, address token, address recipient) public {
        Collection memory collection = fantiumNFT.collections(collectionId);
        uint256 amount = collection.price * quantity;
        _purchase(collectionId, quantity, token, amount, recipient);
    }

    /**
     * @notice Purchase NFTs from the sale with a custom price, checked
     * @param collectionId The collection ID to purchase from.
     * @param quantity The quantity of NFTs to purchase.
     * @param token The token to purchase the NFTs with.
     * @param amount The amount of tokens to purchase the NFTs with.
     * @param recipient The recipient of the NFTs.
     * @param signature The signature of the purchase request.
     */
    function purchase(
        uint256 collectionId,
        uint24 quantity,
        address token,
        uint256 amount,
        address recipient,
        bytes memory signature
    ) public {
        bytes32 hash = keccak256(abi.encode(_msgSender(), collectionId, quantity, token, amount, recipient))
            .toEthSignedMessageHash();
        if (!hasRole(SIGNER_ROLE, hash.recover(signature))) {
            revert InvalidSignature();
        }

        _purchase(collectionId, quantity, token, amount, recipient);
    }
}
