// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./abstracts/FantiumAbstract.sol";
import "./interfaces/IFantiumNFTV1.sol";

/**
 * @title Filtered Minter contract that allows tokens to be minted with ETH
 * for addresses in an allowlist.
 * This is designed to be used with IFantiumNFTV1 contracts.
 * @author MTX stuido AG.
 */

contract FantiumMinterV1 is ReentrancyGuard, FantiumAbstract, Ownable {
    /// Core contract address this minter interacts with
    address public immutable fantium721Address;

    /// This contract handles cores with interface
    IFantiumNFTV1 private immutable fantium721Contract;

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
        fantium721Contract = IFantiumNFTV1(_fantium721Address);
    }

    /*//////////////////////////////////////////////////////////////
                                 KYC
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                                 MINTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Purchases a token from collection `_collectionId` and sets
     * the token's owner to `_to`.
     * @param _to Address to be the new token's owner.
     * @param _collectionId collection ID to mint a token on.
     * @return tokenId Token ID of minted token
     */
    function purchaseTo(address _to, uint256 _collectionId)
        external
        payable
        returns (uint256 tokenId)
    {
        return _purchaseTo(_to, _collectionId);
    }

    /**
     * @notice gas-optimized version of purchaseTo(address,uint256,bytes32[]).
     */
    function _purchaseTo(address _to, uint256 _collectionId)
        public
        payable
        nonReentrant
        returns (uint256 tokenId)
    {
        // CHECKS
        uint24 invocations;
        uint24 maxInvocations;
        uint256 priceInWei;
        (
            invocations,
            maxInvocations,
            priceInWei,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = fantium721Contract.getCollectionData(_collectionId);

        //check if collections invocations is less than max invocations
        require(
            invocations < maxInvocations,
            "Maximum number of invocations reached"
        );

        // load price of token into memory
        uint256 _pricePerTokenInWei = priceInWei;

        // check if msg.value is more or equal to price of token
        require(
            msg.value >= _pricePerTokenInWei,
            "Must send minimum value to mint!"
        );

        /*
         * Check if address is allowed to mint on collection `_collectionId`.
         * If not, check if address is KYCed.
         */
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
                uint256 athleteRevenue_,
                address payable athleteAddress_
            ) = fantium721Contract.getPrimaryRevenueSplits(
                    _collectionId,
                    _pricePerTokenInWei
                );
            // FANtium payment
            if (fantiumRevenue_ > 0) {
                (success_, ) = fantiumAddress_.call{value: fantiumRevenue_}("");
                require(success_, "FANtium payment failed");
            }
            // athlete payment
            if (athleteRevenue_ > 0) {
                (success_, ) = athleteAddress_.call{value: athleteRevenue_}("");
                require(success_, "Artist payment failed");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event AddressAddedToKYC(address indexed _address);
    event AddressRemovedFromKYC(address indexed _address);
}
