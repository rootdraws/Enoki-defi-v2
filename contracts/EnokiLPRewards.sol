// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title EnokiLPStaking
 * @dev Manages ENOKI-ETH LP token staking and SPORE rewards
 * 
 * Staking Flow:
 * 1. Users provide ENOKI-ETH to Uniswap → Get LP tokens
 * 2. Stake LP tokens here → Earn SPORE
 * 3. Use SPORE → Mint Mushrooms
 * 4. Stake Mushrooms → Earn ENOKI (via Geyser)
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EnokiLPStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Core contracts
    IERC20 public immutable lpToken;        // ENOKI-ETH LP token
    IERC20 public immutable sporeToken;     // SPORE reward token
    
    // Staking state
    struct UserInfo {
        uint256 amount;           // LP tokens staked
        uint256 rewardDebt;      // Reward accounting
        uint256 lastStakeTime;   // For potential bonus calculations
    }
    
    // User balances
    mapping(address => UserInfo) public userInfo;
    
    // Global state
    uint256 public totalStaked;
    uint256 public sporePerSecond;         // Reward rate
    uint256 public lastRewardTime;         // Last reward distribution
    uint256 public accSporePerShare;       // Accumulated rewards per share

    // Events
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 amount);
    event RateUpdated(uint256 newRate);

    constructor(
        address _lpToken,
        address _sporeToken,
        uint256 _sporePerSecond
    ) {
        lpToken = IERC20(_lpToken);
        sporeToken = IERC20(_sporeToken);
        sporePerSecond = _sporePerSecond;
        lastRewardTime = block.timestamp;
    }

    /**
     * @dev Update reward variables
     * Must be called before any stake/unstake
     */
    modifier updateReward() {
        if (block.timestamp > lastRewardTime && totalStaked != 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTime;
            uint256 sporeReward = timeElapsed * sporePerSecond;
            accSporePerShare += (sporeReward * 1e12) / totalStaked;
            lastRewardTime = block.timestamp;
        }
        _;
    }

    /**
     * @dev Returns pending SPORE rewards for user
     */
    function pendingRewards(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 _accSporePerShare = accSporePerShare;
        
        if (block.timestamp > lastRewardTime && totalStaked != 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTime;
            uint256 sporeReward = timeElapsed * sporePerSecond;
            _accSporePerShare += (sporeReward * 1e12) / totalStaked;
        }
        
        return (user.amount * _accSporePerShare) / 1e12 - user.rewardDebt;
    }

    /**
     * @dev Stake LP tokens
     */
    function stake(uint256 _amount) external nonReentrant updateReward {
        require(_amount > 0, "Cannot stake 0");
        
        UserInfo storage user = userInfo[msg.sender];
        
        // Harvest existing rewards if any
        if (user.amount > 0) {
            uint256 pending = (user.amount * accSporePerShare) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                sporeToken.safeTransfer(msg.sender, pending);
                emit Harvest(msg.sender, pending);
            }
        }

        // Update user state
        user.amount += _amount;
        user.rewardDebt = (user.amount * accSporePerShare) / 1e12;
        user.lastStakeTime = block.timestamp;
        
        // Update global state
        totalStaked += _amount;
        
        // Transfer LP tokens
        lpToken.safeTransferFrom(msg.sender, address(this), _amount);
        
        emit Stake(msg.sender, _amount);
    }

    /**
     * @dev Unstake LP tokens
     */
    function unstake(uint256 _amount) external nonReentrant updateReward {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Insufficient balance");
        
        // Harvest rewards
        uint256 pending = (user.amount * accSporePerShare) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            sporeToken.safeTransfer(msg.sender, pending);
            emit Harvest(msg.sender, pending);
        }
        
        // Update user state
        user.amount -= _amount;
        user.rewardDebt = (user.amount * accSporePerShare) / 1e12;
        
        // Update global state
        totalStaked -= _amount;
        
        // Return LP tokens
        lpToken.safeTransfer(msg.sender, _amount);
        
        emit Unstake(msg.sender, _amount);
    }

    /**
     * @dev Harvest SPORE rewards without unstaking
     */
    function harvest() external nonReentrant updateReward {
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = (user.amount * accSporePerShare) / 1e12 - user.rewardDebt;
        
        require(pending > 0, "No rewards to harvest");
        
        user.rewardDebt = (user.amount * accSporePerShare) / 1e12;
        sporeToken.safeTransfer(msg.sender, pending);
        
        emit Harvest(msg.sender, pending);
    }

    /**
     * @dev Update SPORE reward rate
     * Can only be called by owner (DAO)
     */
    function setRewardRate(uint256 _sporePerSecond) external onlyOwner updateReward {
        sporePerSecond = _sporePerSecond;
        emit RateUpdated(_sporePerSecond);
    }

    /**
     * @dev Emergency withdraw function
     * Forfeits rewards but returns LP tokens
     */
    function emergencyWithdraw() external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        
        user.amount = 0;
        user.rewardDebt = 0;
        totalStaked -= amount;
        
        lpToken.safeTransfer(msg.sender, amount);
        emit Unstake(msg.sender, amount);
    }
}