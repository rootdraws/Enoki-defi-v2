// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EnokiLPStaking
 * @notice Manages ENOKI-ETH LP token staking and SPORE rewards
 * 
 * @dev Staking Flow:
 * 1. Users provide ENOKI-ETH to Uniswap → Get LP tokens
 * 2. Stake LP tokens here → Earn SPORE
 * 3. Use SPORE → Mint Mushrooms
 * 4. Stake Mushrooms → Earn ENOKI (via Geyser)
 */

contract EnokiLPStaking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Core contracts
    IERC20 public immutable lpToken;        // ENOKI-ETH LP token
    IERC20 public immutable sporeToken;     // SPORE reward token
    
    // Staking state
    struct UserInfo {
        uint256 amount;           // LP tokens staked
        uint256 rewardDebt;       // Reward accounting
        uint256 lastStakeTime;    // For potential bonus calculations
    }
    
    // User balances
    mapping(address => UserInfo) public userInfo;
    
    // Global state
    uint256 public totalStaked;
    uint256 public sporePerSecond;         // Reward rate
    uint256 public lastRewardTime;         // Last reward distribution
    uint256 public accSporePerShare;       // Accumulated rewards per share

    // Constants
    uint256 private constant PRECISION_FACTOR = 1e12;

    // Events
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Harvest(address indexed user, uint256 amount);
    event RateUpdated(uint256 newRate);

    constructor(
        IERC20 _lpToken,
        IERC20 _sporeToken,
        uint256 _sporePerSecond
    ) Ownable(msg.sender) {
        lpToken = _lpToken;
        sporeToken = _sporeToken;
        sporePerSecond = _sporePerSecond;
        lastRewardTime = block.timestamp;
    }

    /**
     * @notice Calculate and update reward variables
     */
    function updatePool() public {
        if (block.timestamp <= lastRewardTime || totalStaked == 0) {
            return;
        }

        uint256 timeElapsed = block.timestamp - lastRewardTime;
        uint256 sporeReward = timeElapsed * sporePerSecond;
        accSporePerShare += (sporeReward * PRECISION_FACTOR) / totalStaked;
        lastRewardTime = block.timestamp;
    }

    /**
     * @notice Returns pending SPORE rewards for a user
     * @param _user Address of the user
     * @return Pending rewards amount
     */
    function pendingRewards(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 tempAccSporePerShare = accSporePerShare;
        
        if (block.timestamp > lastRewardTime && totalStaked != 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTime;
            uint256 sporeReward = timeElapsed * sporePerSecond;
            tempAccSporePerShare += (sporeReward * PRECISION_FACTOR) / totalStaked;
        }
        
        return 
            (user.amount * tempAccSporePerShare) / PRECISION_FACTOR 
            - user.rewardDebt;
    }

    /**
     * @notice Stake LP tokens
     * @param _amount Amount of LP tokens to stake
     */
    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot stake zero");
        
        updatePool();
        
        UserInfo storage user = userInfo[msg.sender];
        
        // Harvest existing rewards if any
        if (user.amount > 0) {
            uint256 pending = 
                (user.amount * accSporePerShare) / PRECISION_FACTOR 
                - user.rewardDebt;
            
            if (pending > 0) {
                sporeToken.safeTransfer(msg.sender, pending);
                emit Harvest(msg.sender, pending);
            }
        }

        // Update user state
        user.amount += _amount;
        user.rewardDebt = (user.amount * accSporePerShare) / PRECISION_FACTOR;
        user.lastStakeTime = block.timestamp;
        
        // Update global state
        totalStaked += _amount;
        
        // Transfer LP tokens
        lpToken.safeTransferFrom(msg.sender, address(this), _amount);
        
        emit Stake(msg.sender, _amount);
    }

    /**
     * @notice Unstake LP tokens
     * @param _amount Amount of LP tokens to unstake
     */
    function unstake(uint256 _amount) external nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "Insufficient balance");
        
        updatePool();
        
        // Harvest rewards
        uint256 pending = 
            (user.amount * accSporePerShare) / PRECISION_FACTOR 
            - user.rewardDebt;
        
        if (pending > 0) {
            sporeToken.safeTransfer(msg.sender, pending);
            emit Harvest(msg.sender, pending);
        }
        
        // Update user state
        user.amount -= _amount;
        user.rewardDebt = (user.amount * accSporePerShare) / PRECISION_FACTOR;
        
        // Update global state
        totalStaked -= _amount;
        
        // Return LP tokens
        lpToken.safeTransfer(msg.sender, _amount);
        
        emit Unstake(msg.sender, _amount);
    }

    /**
     * @notice Harvest SPORE rewards without unstaking
     */
    function harvest() external nonReentrant {
        updatePool();
        
        UserInfo storage user = userInfo[msg.sender];
        uint256 pending = 
            (user.amount * accSporePerShare) / PRECISION_FACTOR 
            - user.rewardDebt;
        
        require(pending > 0, "No rewards to harvest");
        
        user.rewardDebt = (user.amount * accSporePerShare) / PRECISION_FACTOR;
        sporeToken.safeTransfer(msg.sender, pending);
        
        emit Harvest(msg.sender, pending);
    }

    /**
     * @notice Update SPORE reward rate
     * @param _sporePerSecond New reward rate per second
     */
    function setRewardRate(uint256 _sporePerSecond) external onlyOwner {
        updatePool();
        sporePerSecond = _sporePerSecond;
        emit RateUpdated(_sporePerSecond);
    }

    /**
     * @notice Emergency withdraw function
     * @dev Forfeits rewards but returns LP tokens
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