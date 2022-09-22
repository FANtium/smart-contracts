// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin-4.7/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin-4.7/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-4.7/contracts/security/ReentrancyGuard.sol";

import "./FantiumAbstract.sol";

/**
 * @title Filtered Minter contract that allows tokens to be minted with ETH
 * for addresses in a Merkle allowlist and/or allowlist.
 * This is designed to be used with IFantium721V1 contracts.
 * @author MTX stuido AG.
 */

contract FantiumMinterMerkleV1 is ReentrancyGuard, FantiumAbstract {
    using MerkleProof for bytes32[];

    /// Core contract address this minter interacts with
    address public immutable fantium721Address;

    /// This contract handles cores with interface
    IFantium721V1 private immutable fantium721Contract;

    // List of addresses that are allowed to mint
    address[] public kycedAddresses;

    /// collecionId => merkle root
    mapping(uint256 => bytes32) public collectionMerkleRoot;
    /// collecionId => purchaser address => has purchased one or more mints
    mapping(uint256 => mapping(address => bool)) public collecionMintedBy;

    /**
     * @notice Initializes contract to be a Filtered Minter
     * integrated with FANtium core contract
     * at address `_fantium721Address`.
     * @param _fantium721Address FANtium core contract address for
     * which this contract will be a minter.
     */
    constructor(address _fantium721Address) ReentrancyGuard() {
        fantium721Address = _fantium721Address;
        genArtCoreContract = IFantium721V1(_fantium721Address);
    }

    /////////////////////////////////////////
    ///////// MERKLE ROOT FUNCTIONS /////////
    /////////////////////////////////////////

    /**
     * @notice Update the Merkle root for collection `_collectionId`.
     * @param _collectionId collection ID to be updated.
     * @param _root root of Merkle tree defining addresses allowed to mint
     * on collection `_collectionId`.
     */
    function updateMerkleRoot(uint256 _collectionId, bytes32 _root)
        external
        onlyArtist(_collectionId)
    {
        collectionMerkleRoot[_collectionId] = _root;
        emit ConfigValueSet(_collectionId, CONFIG_MERKLE_ROOT, _root);
    }

    /**
     * @notice Returns hashed address (to be used as merkle tree leaf).
     * Included as a public function to enable users to calculate their hashed
     * address in Solidity when generating proofs off-chain.
     * @param _address address to be hashed
     * @return bytes32 hashed address, via keccak256 (using encodePacked)
     */
    function hashAddress(address _address) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_address));
    }

    /**
     * @notice Verify if address is allowed to mint on collection `_collectionId`.
     * @param _collectionId collection ID to be checked.
     * @param _proof Merkle proof for address.
     * @param _address Address to check.
     * @return inAllowlist true only if address is allowed to mint and valid
     * Merkle proof was provided
     */
    function verifyAddress(
        uint256 _collectionId,
        bytes32[] calldata _proof,
        address _address
    ) public view returns (bool) {
        return
            _proof.verifyCalldata(
                collectionMerkleRoot[_collectionId],
                hashAddress(_address)
            );
    }

    /////////////////////////////////////////
    //////////// KYC FUNCTIONS //////////////
    /////////////////////////////////////////

    /**
     * @notice Add address to KYC list.
     * @param _address address to be added to KYC list.
     */
    function addAddressToKYC(address _address) external onlyOwner {
        kycedAddresses.push(_address);
        emit AddressAddedToKYC(_address);
    }

    /**
     * @notice Remove address from KYC list.
     * @param _address address to be removed from KYC list.
     */
    function removeAddressFromKYC(address _address) external onlyOwner {
        for (uint256 i = 0; i < kycedAddresses.length; i++) {
            if (kycedAddresses[i] == _address) {
                kycedAddresses[i] = kycedAddresses[kycedAddresses.length - 1];
                kycedAddresses.pop();
                emit AddressRemovedFromKYC(_address);
                return;
            }
        }
    }

    /**
     * @notice Check if address is KYCed.
     * @param _address address to be checked.
     * @return isKYCed true if address is KYCed.
     */
    function isAddressKYCed(address _address) public view returns (bool) {
        for (uint256 i = 0; i < kycedAddresses.length; i++) {
            if (kycedAddresses[i] == _address) {
                return true;
            }
        }
        return false;
    }

    /////////////////////////////////////////
    ///////// MINTING FUNCTIONS /////////////
    /////////////////////////////////////////

    /**
     * @notice Purchases a token from collection `_collectionId` and sets
     * the token's owner to `_to`.
     * @param _to Address to be the new token's owner.
     * @param _collectionId collection ID to mint a token on.
     * @param _proof Merkle proof.
     * @return tokenId Token ID of minted token
     */
    function purchaseTo(
        address _to,
        uint256 _collectionId,
        bytes32[] calldata _proof
    ) external payable returns (uint256 tokenId) {
        return _purchaseTo(_to, _collectionId, _proof);
    }

    /**
     * @notice gas-optimized version of purchaseTo(address,uint256,bytes32[]).
     */
    function _purchaseTo(
        address _to,
        uint256 _collectionId,
        bytes32[] calldata _proof
    ) public payable nonReentrant returns (uint256 tokenId) {
        // CHECKS

        Collection storage _collection = fantium721Contract.getCollection(
            _collectionId
        );

        //check if collections invocations is less than max invocations
        require(
            _collection.invocations < _collection.maxInvocations,
            "Maximum number of invocations reached"
        );

        // load price of token into memory
        uint256 _pricePerTokenInWei = _collection.priceInWei;

        // check if msg.value is more or equal to price of token
        require(
            msg.value >= _pricePerTokenInWei,
            "Must send minimum value to mint!"
        );

        /*
         * Check if address is allowed to mint on collection `_collectionId`.
         * If not, check if address is KYCed.
         */
        // require valid Merkle proof
        require(
            verifyAddress(_collectionId, _proof, msg.sender),
            "Invalid Merkle proof"
        );

        // or require KYCed address
        require(isAddressKYCed(msg.sender), "Address not KYCed");

        // EFFECTS
        tokenId = fantium721Contract.mint(_to, _collectionId, msg.sender);

        // INTERACTIONS
        _splitFundsETH(_collectionId, _pricePerTokenInWei);

        return tokenId;
    }

    /**
     * @dev splits ETH funds between sender (if refund),
     * FANtium, and athlete for a token purchased on
     * collection `_collectionId`.
     */
    function _splitFundsETH(uint256 _collectionId, uint256 _pricePerTokenInWei)
        internal
    {
        if (msg.value > 0) {
            bool success_;
            // send refund to sender
            uint256 refund = msg.value - _pricePerTokenInWei;
            if (refund > 0) {
                (success_, ) = msg.sender.call{value: refund}("");
                require(success_, "Refund failed");
            }
            // split remaining funds between FANtium and athlete
            (
                uint256 fantiumRevenue_,
                address payable fantiumAddress_,
                uint256 artistRevenue_,
                address payable artistAddress_,
            ) = fantium721Contract.getPrimaryRevenueSplits(
                    _collectionId,
                    _pricePerTokenInWei
                );
            // FANtium payment
            if (fantiumRevenue_ > 0) {
                (success_, ) = fantiumAddress_.call{value: fantiumRevenue_}("");
                require(success_, "FANtium payment failed");
            }
            // artist payment
            if (artistRevenue_ > 0) {
                (success_, ) = artistAddress_.call{value: artistRevenue_}("");
                require(success_, "Artist payment failed");
            }
            }
        }
    }
}
