// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./interfaces/IFantiumNFTV1.sol";
import "./FantiumNFTV1.sol";
import "./FantiumMinterV1.sol";

/**
 * @title Claiming contract that allows payout tokens to be claimed
 * for FAN token holders.
 * @author MTX stuido AG.
 */

 contract FantiumClaimingV1 is ReentrancyGuard, Ownable {

    IERC20 public payoutToken; 

    FantiumNFTV1 public fantiumNFTContract;

    FantiumMinterV1 public fantiumMinterContract;

    // mapping of tokenIds to balances
    mapping(uint256 => uint256) public balances;

    constructor(address _USDC, address _fantiumNFTContract, address _fantiumMinterContract) ReentrancyGuard() {
        payoutToken = ERC20(_USDC);
        fantiumNFTContract = FantiumNFTV1(_fantiumNFTContract);
        fantiumMinterContract = FantiumMinterV1(_fantiumMinterContract);
    }

    function claim(uint256 _tokenId) external{
        // CHECKS

        //check if msg.sender has FAN token Id
        require(msg.sender == fantiumNFTContract.ownerOf(_tokenId), "FantiumClaimingV1: You do not own this token");

        //check if msg.sender is KYCed
        require(fantiumMinterContract.isAddressKYCed(msg.sender), "FantiumClaimingV1: You are not KYCed");

        //check if payouts were claimed for this token
        require(balances[_tokenId] > 0, "FantiumClaimingV1: payout has already been claimed");

        //check if lockTime is over
        //require(fantiumNFTContract.getLockTimeForToken(_tokenId) < block.timestamp, "FantiumClaimingV1: lock time has not passed yet");

        // EFFECTS

        //transfer USDC to msg.sender
        payoutToken.transfer(msg.sender, balances[_tokenId]);
    }

    // update fantiumNFTContract address
    function updateFantiumNFTContract(address _fantiumNFTContract) external onlyOwner {
        fantiumNFTContract = FantiumNFTV1(_fantiumNFTContract);
    }

    // update fantiumMinterContract address
    function updateFantiumMinterContract(address _fantiumMinterContract) external onlyOwner {
        fantiumMinterContract = FantiumMinterV1(_fantiumMinterContract);
    }

    // update payoutToken address
    function updatePayoutToken(address _payoutToken) external onlyOwner {
        payoutToken = ERC20(_payoutToken);
    }

 }