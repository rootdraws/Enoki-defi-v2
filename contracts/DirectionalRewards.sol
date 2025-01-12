// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DirectionalVault} from "./DirectionalVault.sol";

contract DirectionalRewards {
    using SafeERC20 for IERC20;

    // Core contracts
    IERC20 public immutable SPORE;
    DirectionalVault public immutable dVault;
    
    // Rewards state
    uint256 public sporePerSecond;
    uint256 public lastUpdateTime;
    uint256 public accSporePerShare;

    // User accounting
    mapping(address => uint256) public userRewardDebt;
    
    // Events
    event RewardsClaimed(address indexed user, uint256 amount);
    event PositionResult(address indexed user, bool wasCorrect, int256 entryPrice, int256 currentPrice);

    constructor(address _spore, address _dVault) {
        SPORE = IERC20(_spore);
        dVault = DirectionalVault(_dVault);
        lastUpdateTime = block.timestamp;
    }

    function updatePool() public {
        if (block.timestamp <= lastUpdateTime) return;

        uint256 totalShares = dVault.totalLongShares() + dVault.totalShortShares();
        if (totalShares == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        uint256 sporeReward = timeElapsed * sporePerSecond;
        accSporePerShare += (sporeReward * 1e12) / totalShares;
        lastUpdateTime = block.timestamp;
    }

    function pendingSpore(address user) external view returns (uint256) {
        DirectionalVault.Position memory position = dVault.positions(user);
        if (position.shares == 0) return 0;

        uint256 reward = (position.shares * accSporePerShare / 1e12) - userRewardDebt[user];
        
        // Only get rewards if position was correct
        if (!_isPositionCorrect(position)) {
            return 0;
        }

        return reward;
    }

    function _isPositionCorrect(DirectionalVault.Position memory position) internal view returns (bool) {
        int256 currentBtcPrice = dVault.oracle().getPrice(dVault.BTC_FEED_ID());
        int256 priceChange = currentBtcPrice - position.entryPrice;
        
        // LONG is correct if price went up
        // SHORT is correct if price went down
        bool isCorrect = position.direction == DirectionalVault.Direction.LONG ? 
            priceChange > 0 : 
            priceChange < 0;

        emit PositionResult(msg.sender, isCorrect, position.entryPrice, currentBtcPrice);
        
        return isCorrect;
    }

    function claim() external {
        updatePool();
        
        DirectionalVault.Position memory position = dVault.positions(msg.sender);
        require(position.shares > 0, "No position");

        uint256 pending = (position.shares * accSporePerShare / 1e12) - userRewardDebt[msg.sender];
        
        // Only pay rewards if position was correct
        if (_isPositionCorrect(position)) {
            if (pending > 0) {
                SPORE.safeTransfer(msg.sender, pending);
                emit RewardsClaimed(msg.sender, pending);
            }
        }

        userRewardDebt[msg.sender] = position.shares * accSporePerShare / 1e12;
    }

    // Admin: Set emission rate
    function setSporePerSecond(uint256 _sporePerSecond) external {
        // Add access control
        updatePool();
        sporePerSecond = _sporePerSecond;
    }
} 