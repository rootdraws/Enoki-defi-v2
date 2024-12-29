// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title CentralizedRateVote
* @dev Simple admin contract that allows owner to modify pool rates
* 
* Purpose:
* - Central controller for changing rates across pools
* - Likely used for initial/testing phase before decentralized voting
* - Name suggests this may be replaced with proper voting system later
*/

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/IRateVoteable.sol";

contract CentralizedRateVote is OwnableUpgradeSafe {
   using SafeMath for uint256;

   // Constants & State
   uint256 public constant MAX_PERCENTAGE = 100;
   uint256 public votingEnabledTime;  // Unused currently - likely for future voting implementation

   /**
    * @dev Initialize contract and set up ownership
    */
   function initialize() public virtual initializer {
       __Ownable_init();
   }

   /**
    * @dev Owner can change rate multiplier for a pool
    * @param pool The pool to modify
    * @param rateMultiplier New rate value 
    */
   function changeRate(IRateVoteable pool, uint256 rateMultiplier) external onlyOwner {
       pool.changeRate(rateMultiplier);
       emit RateSet(rateMultiplier);
   }

   // Event tracking rate changes
   event RateSet(uint256 rateMultiplier);
}