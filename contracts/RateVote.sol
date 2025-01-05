// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title ModernRateVote
 * @notice Advanced governance contract for token-weighted rate adjustments with enhanced security
 * @dev Implements delegation-aware voting with checkpoints for accurate vote weights
 */

contract ModernRateVote is ReentrancyGuard {
    using Math for uint256;

    // Custom errors with descriptive parameters
    error VotingNotStarted(uint256 currentTime, uint256 startTime);
    error VotingClosed(uint256 currentTime, uint256 epochEnd);
    error AlreadyVoted(address voter, uint256 epoch);
    error InvalidVote(VoteDecision decision);
    error UnauthorizedCaller(address caller);
    error ZeroVotingPower();
    error InvalidParams();
    error VotingPeriodNotEnded(uint256 currentTime, uint256 endTime);
    error RateAdjustmentFailed();

    // Enum for vote decisions with explicit values
    enum VoteDecision { 
        Decrease, // 0
        Increase, // 1
        Tie       // 2
    }

    // Compact struct for vote epoch tracking with explicit types
    struct EpochVote {
        uint64 startTime;           // When the epoch started
        uint64 activeEpoch;         // Current epoch number
        uint128 decreaseVoteWeight; // Total weight for rate decrease
        uint128 increaseVoteWeight; // Total weight for rate increase
        bool resolved;              // Whether epoch has been resolved
    }

    // Events with comprehensive indexed parameters
    event VoteCast(
        address indexed voter,
        uint256 indexed epoch,
        uint256 weight,
        VoteDecision indexed decision,
        uint256 timestamp
    );
    event VoteResolved(
        uint256 indexed epoch,
        VoteDecision indexed decision,
        uint256 newRate,
        uint256 timestamp
    );
    event VoteStarted(
        uint256 indexed epoch,
        uint256 startTime,
        uint256 endTime,
        uint256 totalVotingPower
    );
    event ContractBanStatusUpdated(address indexed account, bool banned);

    // Constants with explicit scaling
    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MAX_RATE_MULTIPLIER = 300;  // 300% = 3x
    uint256 private constant MIN_RATE_MULTIPLIER = 25;   // 25% = 0.25x
    uint256 private constant DECREASE_RATE = 5000;       // 50% in basis points
    uint256 private constant INCREASE_RATE = 15000;      // 150% in basis points

    // Immutable state variables
    ERC20Votes public immutable token;
    IRateAdjustable public immutable rateAdjustablePool;
    uint256 public immutable voteDuration;
    uint256 public immutable votingStartTime;

    // State variables with explicit mappings
    EpochVote private _currentVoteEpoch;
    mapping(address voter => uint256 epoch) private _lastVotedEpoch;
    mapping(address account => bool banned) private _bannedContracts;

    /**
     * @notice Initialize voting parameters
     * @param _token Token contract for vote weighting (must support ERC20Votes)
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
        if (_token == address(0) || 
            _pool == address(0) || 
            _voteDuration == 0 || 
            _startTime <= block.timestamp) revert InvalidParams();

        token = ERC20Votes(_token);
        rateAdjustablePool = IRateAdjustable(_pool);
        voteDuration = _voteDuration;
        votingStartTime = _startTime;

        // Initialize first epoch
        _currentVoteEpoch = EpochVote({
            startTime: uint64(_startTime),
            activeEpoch: 0,
            decreaseVoteWeight: 0,
            increaseVoteWeight: 0,
            resolved: false
        });

        emit VoteStarted(
            0,
            _startTime,
            _startTime + _voteDuration,
            token.getPastTotalSupply(block.number - 1)
        );
    }

    /**
     * @notice Cast a vote for rate adjustment
     * @param decision Vote to decrease or increase rate
     */
    function castVote(VoteDecision decision) external nonReentrant {
        if (decision == VoteDecision.Tie) revert InvalidVote(decision);
        
        _validateVoting();

        // Get voter's token balance using checkpointing
        uint256 voterWeight = token.getPastVotes(msg.sender, _getVotingBlock());
        if (voterWeight == 0) revert ZeroVotingPower();

        // Update vote weights
        unchecked {
            // Safe due to total supply constraints
            if (decision == VoteDecision.Decrease) {
                _currentVoteEpoch.decreaseVoteWeight += uint128(voterWeight);
            } else {
                _currentVoteEpoch.increaseVoteWeight += uint128(voterWeight);
            }
        }

        _lastVotedEpoch[msg.sender] = _currentVoteEpoch.activeEpoch;

        emit VoteCast(
            msg.sender, 
            _currentVoteEpoch.activeEpoch, 
            voterWeight, 
            decision,
            block.timestamp
        );
    }

    /**
     * @notice Resolve current vote and start new epoch
     */
    function resolveVote() external nonReentrant {
        uint256 epochEnd = _currentVoteEpoch.startTime + voteDuration;
        if (block.timestamp < epochEnd) {
            revert VotingPeriodNotEnded(block.timestamp, epochEnd);
        }
        if (_currentVoteEpoch.resolved) revert VotingClosed(block.timestamp, epochEnd);

        VoteDecision decision = _determineVoteOutcome();
        uint256 newRate = _adjustPoolRate(decision);
        _currentVoteEpoch.resolved = true;

        emit VoteResolved(
            _currentVoteEpoch.activeEpoch,
            decision,
            newRate,
            block.timestamp
        );

        _startNewEpoch();
    }

    /**
     * @notice View functions for vote information
     */
    function getCurrentEpoch() external view returns (
        uint64 startTime,
        uint64 activeEpoch,
        uint128 decreaseVoteWeight,
        uint128 increaseVoteWeight,
        bool resolved
    ) {
        return (
            _currentVoteEpoch.startTime,
            _currentVoteEpoch.activeEpoch,
            _currentVoteEpoch.decreaseVoteWeight,
            _currentVoteEpoch.increaseVoteWeight,
            _currentVoteEpoch.resolved
        );
    }

    function getLastVotedEpoch(address voter) external view returns (uint256) {
        return _lastVotedEpoch[voter];
    }

    function isContractBanned(address account) external view returns (bool) {
        return _bannedContracts[account];
    }

    /**
     * @dev Internal functions with enhanced validation
     */
    function _validateVoting() private view {
        if (block.timestamp < votingStartTime) {
            revert VotingNotStarted(block.timestamp, votingStartTime);
        }
        
        uint256 epochEnd = _currentVoteEpoch.startTime + voteDuration;
        if (block.timestamp > epochEnd) {
            revert VotingClosed(block.timestamp, epochEnd);
        }
        
        if (_lastVotedEpoch[msg.sender] == _currentVoteEpoch.activeEpoch) {
            revert AlreadyVoted(msg.sender, _currentVoteEpoch.activeEpoch);
        }
        
        if (_bannedContracts[msg.sender]) {
            revert UnauthorizedCaller(msg.sender);
        }
    }

    function _getVotingBlock() private view returns (uint256) {
        return block.number - 1;
    }

    function _determineVoteOutcome() private view returns (VoteDecision) {
        EpochVote memory epoch = _currentVoteEpoch;
        
        if (epoch.decreaseVoteWeight > epoch.increaseVoteWeight) {
            return VoteDecision.Decrease;
        } else if (epoch.increaseVoteWeight > epoch.decreaseVoteWeight) {
            return VoteDecision.Increase;
        }
        return VoteDecision.Tie;
    }

    function _adjustPoolRate(VoteDecision decision) private returns (uint256) {
        uint256 currentRate = rateAdjustablePool.getCurrentRate();
        uint256 newRate = currentRate;

        if (decision == VoteDecision.Decrease) {
            newRate = (currentRate * DECREASE_RATE) / BASIS_POINTS;
        } else if (decision == VoteDecision.Increase) {
            newRate = (currentRate * INCREASE_RATE) / BASIS_POINTS;
        }

        // Ensure rate stays within acceptable bounds
        newRate = Math.max(MIN_RATE_MULTIPLIER, Math.min(newRate, MAX_RATE_MULTIPLIER));

        try rateAdjustablePool.setRate(newRate) {
            return newRate;
        } catch {
            revert RateAdjustmentFailed();
        }
    }

    function _startNewEpoch() private {
        uint256 newEpochNumber;
        unchecked {
            newEpochNumber = _currentVoteEpoch.activeEpoch + 1;
        }

        _currentVoteEpoch = EpochVote({
            startTime: uint64(block.timestamp),
            activeEpoch: uint64(newEpochNumber),
            decreaseVoteWeight: 0,
            increaseVoteWeight: 0,
            resolved: false
        });

        emit VoteStarted(
            newEpochNumber,
            block.timestamp,
            block.timestamp + voteDuration,
            token.getPastTotalSupply(_getVotingBlock())
        );
    }
}

/**
 * @dev Interface for rate-adjustable pool with explicit returns
 */
interface IRateAdjustable {
    function getCurrentRate() external view returns (uint256 rate);
    function setRate(uint256 newRate) external returns (bool success);
}