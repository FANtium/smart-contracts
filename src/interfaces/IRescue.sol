// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IRescue
 * @notice Interface for rescuing NFTs in emergency situations
 * @dev This interface provides functionality for authorized parties to transfer NFTs to a specified address
 */
interface IRescue {
    /**
     * @notice Emitted when a token is rescued
     * @param tokenId The ID of the rescued token
     * @param recipient The address that received the rescued token
     * @param reason A string explaining why the token was rescued
     */
    event Rescued(uint256 tokenId, address recipient, string reason);

    /**
     * @notice Rescues a single token by transferring it to a specified address
     * @param tokenId The ID of the token to rescue
     * @param reason A string explaining why the token is being rescued
     */
    function rescue(uint256 tokenId, string memory reason) external;

    /**
     * @notice Rescues multiple tokens by transferring them to a specified address
     * @param tokenIds An array of token IDs to rescue
     * @param reason A string explaining why the tokens are being rescued
     */
    function rescueBatch(uint256[] memory tokenIds, string memory reason) external;
}
