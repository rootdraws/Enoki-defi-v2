// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title RateVote
* @dev Governance contract for pool rate adjustments through token-weighted voting
* 
* How Voting Works:
* 1. ENOKI token holders call vote() function directly
* 2. Weight is determined by token balance at epoch start
* 3. Can only vote once per epoch
* 4. After epoch ends, anyone can call resolveVote()
* 5. Winning vote changes pool rates up (150%) or down (50%)
*
* Vote Requirements:
* - Must hold ENOKI tokens at epoch start
* - Must vote within epoch duration
* - Cannot be a banned contract
* - One vote per address per epoch

Rate Voting
├── Token-weighted voting
├── Rate adjustment control
└── Epoch-based voting system

TokenVesting & TokenPool
├── Team/investor vesting
├── Multiple token support
└── Controlled distribution

*/

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./Defensible.sol";
import "./interfaces/IMiniMe.sol";
import "./interfaces/ISporeToken.sol";
import "./interfaces/IRateVoteable.sol";
import "./BannedContractList.sol";

contract RateVote is ReentrancyGuardUpgradeSafe, Defensible {

   /* ========== STATE VARIABLES ========== */
   uint256 public constant MAX_PERCENTAGE = 100;

   // Core voting parameters
   uint256 public votingEnabledTime;           // Global start time for voting system
   uint256 public voteDuration;                // Length of each voting epoch - fixed at initialization
   mapping(address => uint256) lastVoted;      // Tracks last vote by address to prevent duplicate voting

   // Vote epoch tracking
   struct VoteEpoch {
       uint256 startTime;          // When current epoch started
       uint256 activeEpoch;        // Current epoch number (increments after each resolution)
       uint256 increaseVoteWeight; // Total vote weight for rate increase
       uint256 decreaseVoteWeight; // Total vote weight for rate decrease
   }

   VoteEpoch public voteEpoch;

   // Core contracts
   IMiniMe public enokiToken;              // ENOKI token used for vote weight
   IRateVoteable public pool;              // Pool whose rates are being voted on
   BannedContractList public bannedContractList;

   // Rate adjustment parameters
   uint256 public decreaseRateMultiplier;  // 50% - rate if decrease wins
   uint256 public increaseRateMultiplier;  // 150% - rate if increase wins

   /**
    * @dev Initializes the voting contract with core parameters
    * @param _pool Pool contract address
    * @param _enokiToken ENOKI token address for vote weight
    * @param _voteDuration Length of each voting epoch (fixed)
    * @param _votingEnabledTime When voting system becomes active
    * @param _bannedContractList Security contract for blocking malicious contracts
    */
   function initialize(
       address _pool,
       address _enokiToken,
       uint256 _voteDuration,
       uint256 _votingEnabledTime,
       address _bannedContractList
   ) public virtual initializer {
       __ReentrancyGuard_init();

       pool = IRateVoteable(_pool);

       // Set rate change values
       decreaseRateMultiplier = 50;         // 50% of current rate
       increaseRateMultiplier = 150;        // 150% of current rate

       votingEnabledTime = _votingEnabledTime;
       voteDuration = _voteDuration;         // Sets fixed epoch length
       enokiToken = IMiniMe(_enokiToken);

       // Initialize first epoch
       voteEpoch = VoteEpoch({
           startTime: votingEnabledTime,    // First epoch starts when voting enabled
           activeEpoch: 0,                  // Start at epoch 0
           increaseVoteWeight: 0,           // No votes yet
           decreaseVoteWeight: 0            // No votes yet
       });

       bannedContractList = BannedContractList(_bannedContractList);
   }

   /**
    * @dev Submit vote for rate change
    * @param voteId 0=decrease rate, 1=increase rate
    *
    * Vote Process:
    * 1. Checks if sender can vote (timing, not voted, not banned)
    * 2. Gets vote weight from token balance at epoch start
    * 3. Adds weight to appropriate vote total
    * 4. Marks address as voted for this epoch
    * 5. Emits vote event
    */
   function vote(uint256 voteId) external nonReentrant defend(bannedContractList) {
       require(now > votingEnabledTime, "Too early");
       require(now <= voteEpoch.startTime.add(voteDuration), "Vote has ended");
       require(lastVoted[msg.sender] < voteEpoch.activeEpoch, "Already voted");

       // Weight = token balance when epoch started
       uint256 userWeight = enokiToken.balanceOfAt(msg.sender, voteEpoch.startTime);

       // Add weight to appropriate vote
       if (voteId == 0) {
           voteEpoch.decreaseVoteWeight = voteEpoch.decreaseVoteWeight.add(userWeight);
       } else if (voteId == 1) {
           voteEpoch.increaseVoteWeight = voteEpoch.increaseVoteWeight.add(userWeight);
       } else {
           revert("Invalid voteId");
       }

       lastVoted[msg.sender] = voteEpoch.activeEpoch;
       emit Vote(msg.sender, voteEpoch.activeEpoch, userWeight, voteId);
   }

   /**
    * @dev Resolve current vote and start new epoch
    * Can be called by anyone after voteDuration expires
    *
    * Resolution Process:
    * 1. Verify epoch has ended
    * 2. Compare vote weights to determine winner
    * 3. Implement winning rate change
    * 4. Start new epoch
    * 5. Emit resolution event
    */
   function resolveVote() external nonReentrant defend(bannedContractList) {
       require(now >= voteEpoch.startTime.add(voteDuration), "Vote still active");
       
       uint256 decision;
       if (voteEpoch.decreaseVoteWeight > voteEpoch.increaseVoteWeight) {
           // Decrease wins - set rate to 50%
           pool.changeRate(decreaseRateMultiplier);
           decision = 0;
       } else if (voteEpoch.increaseVoteWeight > voteEpoch.decreaseVoteWeight) {
           // Increase wins - set rate to 150%
           pool.changeRate(increaseRateMultiplier);
           decision = 1;
       } else {
           // Tie - no change
           decision = 2;
       }

       emit VoteResolved(voteEpoch.activeEpoch, decision);

       // Start new epoch
       voteEpoch.activeEpoch = voteEpoch.activeEpoch.add(1);
       voteEpoch.decreaseVoteWeight = 0;
       voteEpoch.increaseVoteWeight = 0;
       voteEpoch.startTime = now;

       emit VoteStarted(voteEpoch.activeEpoch, voteEpoch.startTime, voteEpoch.startTime.add(voteDuration));
   }

   // Events for tracking votes and epochs
   event Vote(address indexed user, uint256 indexed epoch, uint256 weight, uint256 indexed vote);
   event VoteResolved(uint256 indexed epoch, uint256 indexed decision);
   event VoteStarted(uint256 indexed epoch, uint256 startTime, uint256 endTime);
}