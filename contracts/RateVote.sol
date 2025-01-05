// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ModernRateVote
 * @dev Advanced governance contract for token-weighted rate adjustments
 * 
 * Features:
 * - Token-weighted voting mechanism
 * - Epoch-based voting system
 * - Flexible rate adjustment
 * - Robust security checks
 * 
 * Core Voting Mechanism:
 * 1. Token holders vote within a specific epoch
 * 2. Vote weight determined by token balance
 * 3. Single vote per address per epoch
 * 4. Rate can be increased or decreased based on voting results
 */
contract ModernRateVote {
    // Custom error types for gas-efficient error handling
    error VotingNotStarted();
    error VotingClosed();
    error AlreadyVoted();
    error InvalidVote();
    error UnauthorizedCaller();

    // Enum for vote decisions
    enum VoteDecision { Decrease, Increase, Tie }

    // Compact struct for vote epoch tracking
    struct EpochVote {
        uint64 startTime;          // When the epoch started
        uint64 activeEpoch;        // Current epoch number
        uint128 decreaseVoteWeight;// Total weight for rate decrease
        uint128 increaseVoteWeight;// Total weight for rate increase
    }

    // Events using indexed parameters for efficient filtering
    event VoteCast(
        address indexed voter, 
        uint256 indexed epoch, 
        uint256 weight, 
        VoteDecision decision
    );
    event VoteResolved(
        uint256 indexed epoch, 
        VoteDecision indexed decision
    );
    event VoteStarted(
        uint256 indexed epoch, 
        uint256 startTime, 
        uint256 endTime
    );

    // Immutable and constant parameters
    uint256 private constant MAX_RATE_MULTIPLIER = 300;  // Maximum 300%
    uint256 private constant MIN_RATE_MULTIPLIER = 25;   // Minimum 25%

    // State variables
    address public immutable token;
    address public immutable rateAdjustablePool;
    uint256 public immutable voteDuration;
    uint256 public immutable votingStartTime;

    // Tracking vote participation
    EpochVote private _currentVoteEpoch;
    mapping(address => uint256) private _lastVotedEpoch;
    mapping(address => bool) private _bannedContracts;

    /**
     * @dev Constructor to initialize voting parameters
     * @param _token Token contract for vote weighting
     * @param _pool Pool whose rates will be adjusted
     * @param _voteDuration Duration of each voting epoch
     * @param _startTime When voting becomes active
     */
    constructor(
        address _token, 
        address _pool, 
        uint256 _voteDuration, 
        uint256 _startTime
    ) {
        if (_token == address(0) || _pool == address(0)) revert InvalidVote();

        token = _token;
        rateAdjustablePool = _pool;
        voteDuration = _voteDuration;
        votingStartTime = _startTime;

        // Initialize first epoch
        _currentVoteEpoch = EpochVote({
            startTime: uint64(_startTime),
            activeEpoch: 0,
            decreaseVoteWeight: 0,
            increaseVoteWeight: 0
        });
    }

    /**
     * @dev Cast a vote for rate adjustment
     * @param decision Vote to decrease or increase rate
     */
    function castVote(VoteDecision decision) external {
        // Validate voting conditions
        _validateVoting();

        // Get voter's token balance at epoch start
        uint256 voterWeight = _getVoterWeight(msg.sender);

        // Update vote weights
        if (decision == VoteDecision.Decrease) {
            _currentVoteEpoch.decreaseVoteWeight += uint128(voterWeight);
        } else if (decision == VoteDecision.Increase) {
            _currentVoteEpoch.increaseVoteWeight += uint128(voterWeight);
        } else {
            revert InvalidVote();
        }

        // Mark voter for this epoch
        _lastVotedEpoch[msg.sender] = _currentVoteEpoch.activeEpoch;

        // Emit vote event
        emit VoteCast(msg.sender, _currentVoteEpoch.activeEpoch, voterWeight, decision);
    }

    /**
     * @dev Resolve current vote and start new epoch
     */
    function resolveVote() external {
        // Ensure voting period has ended
        if (block.timestamp < _currentVoteEpoch.startTime + voteDuration) {
            revert VotingClosed();
        }

        // Determine vote outcome
        VoteDecision decision = _determineVoteOutcome();

        // Adjust pool rate if there's a clear winner
        _adjustPoolRate(decision);

        // Emit resolution event
        emit VoteResolved(_currentVoteEpoch.activeEpoch, decision);

        // Start new epoch
        _startNewEpoch();
    }

    /**
     * @dev Validate voting eligibility
     */
    function _validateVoting() private view {
        if (block.timestamp < votingStartTime) revert VotingNotStarted();
        if (block.timestamp > _currentVoteEpoch.startTime + voteDuration) revert VotingClosed();
        if (_lastVotedEpoch[msg.sender] == _currentVoteEpoch.activeEpoch) revert AlreadyVoted();
        if (_isContractBanned(msg.sender)) revert UnauthorizedCaller();
    }

    /**
     * @dev Get voter's token weight
     * @param voter Address to check
     * @return Token balance at epoch start
     */
    function _getVoterWeight(address voter) private view returns (uint256) {
        // Placeholder for token balance check
        // In actual implementation, use token's balanceOfAt method
        return IERC20(token).balanceOf(voter);
    }

    /**
     * @dev Determine vote outcome
     * @return Voting decision
     */
    function _determineVoteOutcome() private view returns (VoteDecision) {
        if (_currentVoteEpoch.decreaseVoteWeight > _currentVoteEpoch.increaseVoteWeight) {
            return VoteDecision.Decrease;
        } else if (_currentVoteEpoch.increaseVoteWeight > _currentVoteEpoch.decreaseVoteWeight) {
            return VoteDecision.Increase;
        }
        return VoteDecision.Tie;
    }

    /**
     * @dev Adjust pool rate based on vote outcome
     * @param decision Voting decision
     */
    function _adjustPoolRate(VoteDecision decision) private {
        uint256 currentRate = IRateAdjustable(rateAdjustablePool).getCurrentRate();
        uint256 newRate;

        if (decision == VoteDecision.Decrease) {
            newRate = (currentRate * 50) / 100;  // 50% reduction
        } else if (decision == VoteDecision.Increase) {
            newRate = (currentRate * 150) / 100;  // 150% increase
        } else {
            return;  // Tie - no change
        }

        // Ensure rate stays within acceptable bounds
        newRate = _constrainRate(newRate);
        IRateAdjustable(rateAdjustablePool).setRate(newRate);
    }

    /**
     * @dev Constrain rate to acceptable range
     * @param rate Proposed new rate
     * @return Constrained rate
     */
    function _constrainRate(uint256 rate) private pure returns (uint256) {
        return _clamp(rate, MIN_RATE_MULTIPLIER, MAX_RATE_MULTIPLIER);
    }

    /**
     * @dev Start a new voting epoch
     */
    function _startNewEpoch() private {
        _currentVoteEpoch = EpochVote({
            startTime: uint64(block.timestamp),
            activeEpoch: _currentVoteEpoch.activeEpoch + 1,
            decreaseVoteWeight: 0,
            increaseVoteWeight: 0
        });

        emit VoteStarted(
            _currentVoteEpoch.activeEpoch, 
            block.timestamp, 
            block.timestamp + voteDuration
        );
    }

    /**
     * @dev Check if an address is a banned contract
     * @param account Address to check
     * @return Whether the address is banned
     */
    function _isContractBanned(address account) private view returns (bool) {
        return _bannedContracts[account];
    }

    /**
     * @dev Utility function to clamp a value between min and max
     * @param value Value to clamp
     * @param min Minimum allowed value
     * @param max Maximum allowed value
     * @return Clamped value
     */
    function _clamp(uint256 value, uint256 min, uint256 max) private pure returns (uint256) {
        return value < min ? min : (value > max ? max : value);
    }

    // Interface for rate-adjustable pool
    interface IRateAdjustable {
        function getCurrentRate() external view returns (uint256);
        function setRate(uint256 newRate) external;
    }

    // Minimal ERC20 interface for token balance check
    interface IERC20 {
        function balanceOf(address account) external view returns (uint256);
    }
}