// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ECDSAUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import { CommonBase } from "forge-std/Base.sol";

/**
 * @title EIP712Domain
 * @dev Struct representing the EIP-712 domain separator parameters
 * @param name The name of the contract
 * @param version The version of the contract
 * @param chainId The chain ID of the network
 * @param verifyingContract The address of the contract that will verify the signature
 */
struct EIP712Domain {
    string name;
    string version;
    uint256 chainId;
    address verifyingContract;
}

/**
 * @title EIP712Signer
 * @dev Contract for handling EIP-712 typed data signatures
 * @notice This contract provides utilities for creating and verifying EIP-712 typed data signatures
 */
contract EIP712Signer is CommonBase {
    bytes32 constant EIP712DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    /**
     * @dev Returns the domain separator for EIP-712 typed data
     * @param domain The EIP712Domain struct containing domain parameters
     * @return The domain separator hash
     */
    function _domainSeparatorV4(EIP712Domain memory domain) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256(bytes(domain.name)),
                keccak256(bytes(domain.version)),
                domain.chainId,
                domain.verifyingContract
            )
        );
    }

    /**
     * @dev Returns the hash of the typed data
     * @param domainSeparator The domain separator hash
     * @param structHash The hash of the struct data
     * @return The hash of the typed data
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    /**
     * @dev Signs typed data using EIP-712
     * @param privateKey The private key to sign with
     * @param domain The EIP712Domain struct containing domain parameters
     * @param structHash The hash of the struct data
     * @return v The recovery byte of the signature
     * @return r The first 32 bytes of the signature
     * @return s The second 32 bytes of the signature
     */
    function typedSign(
        uint256 privateKey,
        EIP712Domain memory domain,
        bytes32 structHash
    )
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 digest = ECDSAUpgradeable.toTypedDataHash(_domainSeparatorV4(domain), structHash);
        (v, r, s) = vm.sign(privateKey, digest);
    }

    /**
     * @dev Signs typed data using EIP-712 and returns the packed signature
     * @param privateKey The private key to sign with
     * @param domain The EIP712Domain struct containing domain parameters
     * @param structHash The hash of the struct data
     * @return The packed signature (r, s, v)
     */
    function typedSignPacked(
        uint256 privateKey,
        EIP712Domain memory domain,
        bytes32 structHash
    )
        internal
        pure
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = typedSign(privateKey, domain, structHash);
        return abi.encodePacked(r, s, v);
    }
}
