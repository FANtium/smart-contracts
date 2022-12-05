// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../FantiumNFTV1.sol";

/**
 * @title Claiming contract that allows payout tokens to be claimed
 * for FAN token holders.
 * @author MTX stuido AG.
 */

contract FantiumClaimingV1 is UUPSUpgradeable, Ownable {
    IERC20 public payoutToken;

    FantiumNFTV1 public fantiumNFTContract;

    // mapping of tokenIds to balances
    mapping(uint256 => uint256) public balances;

    /*///////////////////////////////////////////////////////////////
                            UUPS UPGRADEABLE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes contract.
     * @param _tokenName Name of token.
     * @param _tokenSymbol Token symbol.
     * @param _startingCollectionId The initial next collection ID.
     * @dev _startingcollectionId should be set to a value much, much less than
     * max(uint248) to avoid overflow when adding to it.
     */
    ///@dev no constructor in upgradable contracts. Instead we have initializers
    function initialize(address _payoutToken, address _fantiumNFTContract)
        public
        initializer
    {
        payoutToken = ERC20(_payoutToken);
        fantiumNFTContract = FantiumNFTV1(_fantiumNFTContract);
    }

    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /*///////////////////////////////////////////////////////////////
                            CLAIMING
    //////////////////////////////////////////////////////////////*/

    function claim(uint256 _tokenId) external {
        // CHECKS

        //check if msg.sender has FAN token Id
        require(
            msg.sender == fantiumNFTContract.ownerOf(_tokenId),
            "FantiumClaimingV1: You do not own this token"
        );

        //check if msg.sender is KYCed
        // require(
        //     fantiumNFTContract.isAddressKYCed(msg.sender),
        //     "FantiumClaimingV1: You are not KYCed"
        // );

        //check if payouts were claimed for this token
        require(
            balances[_tokenId] > 0,
            "FantiumClaimingV1: payout has already been claimed"
        );

        //check if lockTime is over
        //require(fantiumNFTContract.getLockTimeForToken(_tokenId) < block.timestamp, "FantiumClaimingV1: lock time has not passed yet");

        // EFFECTS
        uint256 balanceToSend = balances[_tokenId];
        balances[_tokenId] = 0;

        // INTERACTIONS
        //transfer USDC to msg.sender
        payoutToken.transfer(msg.sender, balanceToSend);
    }

    /*///////////////////////////////////////////////////////////////
                            PAY
    //////////////////////////////////////////////////////////////*/

    function addTournamentEarnings(uint256 _tokenId, uint256 _amount) external {
        // CHECKS

        //check if _tokenId exists
        // require(
        //     fantiumNFTContract.exists(_tokenId),
        //     "FantiumClaimingV1: Token does not exist"
        // );

        //check if msg.sender is the collection's athlete
        // require(
        //     msg.sender ==
        //         fantiumNFTContract
        //             .getCollectionForTokenId(_tokenId)
        //             .athleteAddress,
        //     "FantiumClaimingV1: You are not FantiumNFT contract"
        // );
        
        require(payoutToken.transferFrom(msg.sender, address(this), _amount), "FantiumClaimingV1: transferFrom failed");

        // EFFECTS
        balances[_tokenId] = balances[_tokenId] + _amount;
    }

    /*///////////////////////////////////////////////////////////////
                            ADMIN
    //////////////////////////////////////////////////////////////*/

    // update fantiumNFTContract address
    function updateFantiumNFTContract(address _fantiumNFTContract)
        external
        onlyOwner
    {
        fantiumNFTContract = FantiumNFTV1(_fantiumNFTContract);
    }

    // update payoutToken address
    function updatePayoutToken(address _payoutToken) external onlyOwner {
        payoutToken = ERC20(_payoutToken);
    }
}
