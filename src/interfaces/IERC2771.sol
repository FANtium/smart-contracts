// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/**
 * @title IERC2771
 * @notice Interface for ERC-2771 meta-transaction recipients.
 * @dev See https://eips.ethereum.org/EIPS/eip-2771
 */
interface IERC2771 {
    /**
     * @notice Returns whether the given address is a trusted forwarder.
     * @param forwarder Address to check.
     * @return True if the address is a trusted forwarder.
     */
    function isTrustedForwarder(address forwarder) external view returns (bool);
}
