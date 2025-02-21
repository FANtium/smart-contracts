// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IRescue } from "src/interfaces/IRescue.sol";

/**
 * @title Rescue
 * @author Mathieu Bour - FANtium AG
 * @notice Utility contract for rescuing tokens from the contract
 * @dev This contract is intended to be used as an internal utility for contracts that need to rescue tokens from the
 * contract. It is not intended to be used as a standalone contract.
 */
abstract contract Rescue is IRescue {
    /**
     * @notice Authorizes a rescue of a token by checking if the sender has the DEFAULT_ADMIN_ROLE
     * @param tokenId The ID of the token to rescue
     * @param recipient The address that received the rescued token
     * @param reason A string explaining why the token is being rescued
     */
    function _authorizeRescue(uint256 tokenId, address recipient, string calldata reason) internal virtual;

    /**
     * @notice Rescues a single token by transferring it to a specified address
     * @param tokenId The ID of the token to rescue
     * @param recipient The address that received the rescued token
     * @param reason A string explaining why the token was rescued
     */
    function _rescue(uint256 tokenId, address recipient, string calldata reason) internal virtual;

    /**
     * @notice Rescues a single token by transferring it to a specified address
     * @param tokenId The ID of the token to rescue
     * @param recipient The address that received the rescued token
     * @param reason A string explaining why the token was rescued
     */
    function _doRescue(uint256 tokenId, address recipient, string calldata reason) internal {
        _authorizeRescue(tokenId, recipient, reason);
        _rescue(tokenId, recipient, reason);
        emit Rescued(tokenId, recipient, reason);
    }

    /**
     * @notice Rescues a single token by transferring it to a specified address
     * @param tokenId The ID of the token to rescue
     * @param reason A string explaining why the token is being rescued
     */
    function rescue(uint256 tokenId, string calldata reason) external {
        _doRescue(tokenId, msg.sender, reason);
    }

    /**
     * @notice Rescues multiple tokens by transferring them to a specified address
     * @param tokenIds An array of token IDs to rescue
     * @param reason A string explaining why the tokens are being rescued
     */
    function rescueBatch(uint256[] memory tokenIds, string calldata reason) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _doRescue(tokenIds[i], msg.sender, reason);
        }
    }
}
