// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRateVoteable.sol";

/**
 * @title CentralizedRateVote
 * @dev Simple admin contract that allows owner to modify pool rates
 * 
 * Purpose:
 * - Central controller for changing rates across pools
 * - Likely used for initial/testing phase before decentralized voting
 * - Name suggests this may be replaced with proper voting system later
 */
contract CentralizedRateVote is Ownable {
    // Constants
    uint256 public constant MAX_PERCENTAGE = 100;
    
    // Unused state variable for potential future voting implementation
    uint256 public votingEnabledTime;

    // Constructor to set initial owner
    constructor() Ownable(msg.sender) {}

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