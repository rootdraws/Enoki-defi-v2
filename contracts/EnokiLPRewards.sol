// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

// File Modernized by Claude.AI Sonnet on 1/4/25.

/**
 * @title EnokiLPStaking
 * @notice LP token staking with SPORE rewards for Enoki ecosystem
 * @dev Manages ENOKI-ETH LP staking to earn SPORE rewards
 * @custom:security-contact security@example.com
 
 This is an advanced LP token staking contract for the Enoki ecosystem with sophisticated reward mechanics:

Key Features:
- Stake ENOKI-ETH LP tokens
- Earn SPORE tokens as rewards
- Dynamic reward rate management
- Comprehensive staking tracking

Core Mechanics:
1. Staking Functionality
- Minimum stake amount (0.001 LP)
- One-hour harvest delay
- Automatic reward calculation
- Emergency withdrawal option

2. Security Mechanisms
- Reentrancy protection
- Pausable contract
- Owner-controlled reward rates
- Maximum reward rate limit
- Zero-address and amount checks

3. Advanced Reward Accounting
- Precise per-share reward tracking
- Pending rewards calculation
- Total rewards distribution tracking

Unique Design Elements:
- Tracks detailed user staking information
- Flexible reward distribution
- Allows owner to adjust reward rates
- Multiple safety and emergency controls

The contract provides a robust, flexible mechanism for liquidity providers to earn rewards in the Enoki DeFi ecosystem.
 
 */

contract EnokiLPStaking is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @dev User staking information
    struct UserInfo {
        uint256 amount;           // LP tokens staked
        uint256 rewardDebt;       // Reward debt for accurate reward calculation
        uint256 lastStakeTime;    // Timestamp of last stake
        uint256 totalHarvested;   // Total rewards harvested
        uint256 lastHarvestTime;  // Timestamp of last harvest
    }

    /// @dev Core protocol tokens
    IERC20 public immutable lpToken;        // ENOKI-ETH LP token
    IERC20 public immutable sporeToken;     // SPORE reward token

    /// @dev Staking configuration
    uint256 public constant PRECISION_FACTOR = 1e12;
    uint256 public constant MIN_STAKE_AMOUNT = 1e15;    // 0.001 LP minimum
    uint256 public constant HARVEST_DELAY = 1 hours;    // Minimum time between harvests
    uint256 public constant MAX_REWARD_RATE = 1e20;     // Maximum rewards/second

    /// @dev Staking state
    mapping(address => UserInfo) public userInfo;
    uint256 public totalStaked;
    uint256 public sporePerSecond;         // Current reward rate
    uint256 public lastRewardTime;         // Last reward update time
    uint256 public accSporePerShare;       // Accumulated rewards per share
    uint256 public totalRewardsDistributed;

    /// @dev Events
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        uint256 newTotal
    );
    
    event Unstaked(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        uint256 newTotal
    );
    
    event RewardsHarvested(
        address indexed user,
        uint256 amount,
        uint256 timestamp,
        uint256 totalHarvested
    );
    
    event RewardRateUpdated(
        uint256 oldRate,
        uint256 newRate,
        uint256 timestamp
    );
    
    event EmergencyWithdraw(
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    /// @dev Custom errors
    error ZeroAmount();
    error InsufficientBalance();
    error NoRewardsAvailable();
    error TooSoonToHarvest();
    error InvalidRewardRate();
    error StakeTooSmall();
    error MaxRewardRateExceeded();

    /**
     * @notice Initialize staking contract
     * @param _lpToken LP token contract address
     * @param _sporeToken Reward token contract address
     * @param _sporePerSecond Initial reward rate per second
     */
    constructor(
        IERC20 _lpToken,
        IERC20 _sporeToken,
        uint256 _sporePerSecond
    ) Ownable(msg.sender) {
        if (address(_lpToken) == address(0) || address(_sporeToken) == address(0)) {
            revert ZeroAmount();
        }
        if (_sporePerSecond > MAX_REWARD_RATE) {
            revert MaxRewardRateExceeded();
        }

        lpToken = _lpToken;
        sporeToken = _sporeToken;
        sporePerSecond = _sporePerSecond;
        lastRewardTime = block.timestamp;
        
        _pause(); // Start paused for safety
    }

    /**
     * @notice Update rewards accounting
     * @dev Must be called before any state changes
     */
    function updatePool() public {
        if (block.timestamp <= lastRewardTime || totalStaked == 0) {
            return;
        }

        uint256 timeElapsed = block.timestamp - lastRewardTime;
        uint256 sporeReward = timeElapsed * sporePerSecond;
        accSporePerShare += (sporeReward * PRECISION_FACTOR) / totalStaked;
        totalRewardsDistributed += sporeReward;
        lastRewardTime = block.timestamp;
    }

    /**
     * @notice Calculate pending rewards for user
     * @param _user Address to check rewards for
     * @return Pending SPORE rewards
     */
    function pendingRewards(
        address _user
    ) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 tempAccSporePerShare = accSporePerShare;
        
        if (block.timestamp > lastRewardTime && totalStaked != 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTime;
            uint256 sporeReward = timeElapsed * sporePerSecond;
            tempAccSporePerShare += (sporeReward * PRECISION_FACTOR) / totalStaked;
        }
        
        return (user.amount * tempAccSporePerShare) / PRECISION_FACTOR - user.rewardDebt;
    }

    /**
     * @notice Stake LP tokens
     * @param _amount Amount to stake
     */
    function stake(
        uint256 _amount
    ) external nonReentrant whenNotPaused {
        if (_amount == 0) revert ZeroAmount();
        if (_amount < MIN_STAKE_AMOUNT) revert StakeTooSmall();
        
        updatePool();
        
        UserInfo storage user = userInfo[msg.sender];
        
        // Harvest existing rewards if any
        if (user.amount > 0) {
            uint256 pending = (user.amount * accSporePerShare) / PRECISION_FACTOR - user.rewardDebt;
            if (pending > 0) {
                _harvestRewards(pending);
            }
        }

        // Update user state
        user.amount += _amount;
        user.rewardDebt = (user.amount * accSporePerShare) / PRECISION_FACTOR;
        user.lastStakeTime = block.timestamp;
        
        // Update global state
        totalStaked += _amount;
        
        // Transfer tokens
        lpToken.safeTransferFrom(msg.sender, address(this), _amount);
        
        emit Staked(msg.sender, _amount, block.timestamp, totalStaked);
    }

    /**
     * @notice Unstake LP tokens
     * @param _amount Amount to unstake
     */
    function unstake(
        uint256 _amount
    ) external nonReentrant whenNotPaused {
        UserInfo storage user = userInfo[msg.sender];
        if (_amount == 0) revert ZeroAmount();
        if (user.amount < _amount) revert InsufficientBalance();
        
        updatePool();
        
        // Harvest rewards
        uint256 pending = (user.amount * accSporePerShare) / PRECISION_FACTOR - user.rewardDebt;
        if (pending > 0) {
            _harvestRewards(pending);
        }
        
        // Update state
        user.amount -= _amount;
        user.rewardDebt = (user.amount * accSporePerShare) / PRECISION_FACTOR;
        totalStaked -= _amount;
        
        // Transfer tokens
        lpToken.safeTransfer(msg.sender, _amount);
        
        emit Unstaked(msg.sender, _amount, block.timestamp, totalStaked);
    }

    /**
     * @notice Harvest accumulated rewards
     */
    function harvest() external nonReentrant whenNotPaused {
        if (block.timestamp < userInfo[msg.sender].lastHarvestTime + HARVEST_DELAY) {
            revert TooSoonToHarvest();
        }
        
        updatePool();
        
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = (user.amount * accSporePerShare) / PRECISION_FACTOR - user.rewardDebt;
        
        if (pending == 0) revert NoRewardsAvailable();
        
        _harvestRewards(pending);
        user.rewardDebt = (user.amount * accSporePerShare) / PRECISION_FACTOR;
    }

    /**
     * @dev Internal reward distribution
     */
    function _harvestRewards(uint256 _amount) internal {
        UserInfo storage user = userInfo[msg.sender];
        
        sporeToken.safeTransfer(msg.sender, _amount);
        user.totalHarvested += _amount;
        user.lastHarvestTime = block.timestamp;
        
        emit RewardsHarvested(
            msg.sender,
            _amount,
            block.timestamp,
            user.totalHarvested
        );
    }

    /**
     * @notice Update reward rate
     * @param _sporePerSecond New rewards per second
     */
    function setRewardRate(
        uint256 _sporePerSecond
    ) external onlyOwner {
        if (_sporePerSecond > MAX_REWARD_RATE) revert MaxRewardRateExceeded();
        
        updatePool();
        uint256 oldRate = sporePerSecond;
        sporePerSecond = _sporePerSecond;
        
        emit RewardRateUpdated(oldRate, _sporePerSecond, block.timestamp);
    }

    /**
     * @notice Emergency withdraw without harvesting rewards
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        if (amount == 0) revert ZeroAmount();
        
        // Reset user state
        user.amount = 0;
        user.rewardDebt = 0;
        totalStaked -= amount;
        
        // Return LP tokens
        lpToken.safeTransfer(msg.sender, amount);
        
        emit EmergencyWithdraw(msg.sender, amount, block.timestamp);
    }

    /**
     * @notice Pause staking functionality
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Resume staking functionality
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdraw stuck tokens
     * @param _token Token to withdraw
     * @param _amount Amount to withdraw
     * @param _recipient Address to receive tokens
     */
    function emergencyWithdrawToken(
        IERC20 _token,
        uint256 _amount,
        address _recipient
    ) external onlyOwner {
        if (_recipient == address(0)) revert ZeroAmount();
        _token.safeTransfer(_recipient, _amount);
    }
}