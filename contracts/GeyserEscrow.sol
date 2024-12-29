// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title GeyserEscrow
* @dev Manages the locking of ENOKI tokens into the geyser reward system
* Can be modified to support multiple reward tokens

TOKEN FLOW

ETH Staking → Earn SPORE → Mint Mushrooms → Stake in Geyser → Earn ENOKI

*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "./EnokiGeyser.sol";

contract GeyserEscrow is Ownable {
   // Reference to main geyser contract
   EnokiGeyser public geyser;

   // To add multiple token support:
   // mapping(address => bool) public allowedRewardTokens;
   // event RewardTokenAdded(address token);
   // event RewardTokenRemoved(address token);

   constructor(EnokiGeyser geyser_) public {
       geyser = geyser_;
       // If adding multiple tokens:
       // allowedRewardTokens[address(geyser.getDistributionToken())] = true;
   }

   // To add new reward tokens:
   // function addRewardToken(address tokenAddress) external onlyOwner {
   //     allowedRewardTokens[tokenAddress] = true;
   //     emit RewardTokenAdded(tokenAddress);
   // }

   // function removeRewardToken(address tokenAddress) external onlyOwner {
   //     allowedRewardTokens[tokenAddress] = false;
   //     emit RewardTokenRemoved(tokenAddress);
   // }

   /**
    * @dev Locks ENOKI tokens into the geyser
    * @param amount Amount of tokens to lock
    * @param durationSec Duration tokens are locked for
    *
    * For multiple tokens, would modify to:
    * function lockTokens(
    *     address tokenAddress,
    *     uint256 amount,
    *     uint256 durationSec
    * )
    */
   function lockTokens(
       uint256 amount,
       uint256 durationSec
   ) external onlyOwner {
       // For multiple tokens:
       // require(allowedRewardTokens[tokenAddress], "Token not allowed");
       // IERC20 distributionToken = IERC20(tokenAddress);

       IERC20 distributionToken = geyser.getDistributionToken();
       distributionToken.approve(address(geyser), amount);

       geyser.lockTokens(amount, durationSec);
   }
}