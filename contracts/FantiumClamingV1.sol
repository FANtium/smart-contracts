// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./interfaces/IFantiumNFTV1.sol";
import "./FantiumNFTV1.sol";

/**
 * @title Claiming contract that allows tokens to be claimed
 * for FAN token holders.
 * @author MTX stuido AG.
 */

 contract FantiumClaimingV1 is ReentrancyGuard, Ownable {

    IERC20 public USDC; 

    FantiumNFTV1 public fantiumNFTContract;

    // mapping of tokenIds to balances
    mapping(uint256 => uint256) public balances;

    constructor(address _USDC, address _fantiumNFTContract) ReentrancyGuard() {
        USDC = ERC20(_USDC);
        fantiumNFTContract = FantiumNFTV1(_fantiumNFTContract);
    }

    function claim(uint256 _tokenId) external {
        // CHECKS

        //check if msg.sender has FAN token Id
        require(msg.sender == fantiumNFTContract.ownerOf(_tokenId), "FantiumClaimingV1: You do not own this token");

        //check if specific has claimed
        //require(fantiumNFTContract.getClaimingStatusForToken(_tokenId) == false, "FantiumClaimingV1: payout has already been claimed");
        // or check if balance is 0
        require(balances[_tokenId] > 0, "FantiumClaimingV1: payout has already been claimed");

        //check if lockTime is over
        //require(fantiumNFTContract.getLockTimeForToken(_tokenId) < block.timestamp, "FantiumClaimingV1: lock time has not passed yet");

        // EFFECTS

        //transfer USDC to msg.sender
        USDC.transfer(msg.sender, balances[_tokenId]);
    }

 }