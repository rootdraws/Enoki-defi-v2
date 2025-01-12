// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BTCNLPVault} from "./BTCNLPVault.sol";

contract SporeRewards {
    IERC20 public immutable SPORE;
    BTCNLPVault public immutable vault;
    
    uint256 public sporePerSecond;
    uint256 public lastUpdateTime;
    uint256 public accSporePerShare;

    mapping(address => uint256) public userRewardDebt;

    event RewardsClaimed(address indexed user, uint256 amount);
    event PoolUpdated(uint256 timestamp, uint256 accSporePerShare);

    constructor(address _spore, address _vault) {
        SPORE = IERC20(_spore);
        vault = BTCNLPVault(_vault);
        lastUpdateTime = block.timestamp;
    }

    function updatePool() public {
        if (block.timestamp <= lastUpdateTime) return;

        uint256 lpSupply = vault.totalSupply();
        if (lpSupply == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        uint256 sporeReward = timeElapsed * sporePerSecond;
        accSporePerShare += (sporeReward * 1e12) / lpSupply;
        lastUpdateTime = block.timestamp;

        emit PoolUpdated(block.timestamp, accSporePerShare);
    }

    function pendingSpore(address user) external view returns (uint256) {
        uint256 userShares = vault.balanceOf(user);
        return (userShares * accSporePerShare / 1e12) - userRewardDebt[user];
    }

    function claim() external {
        updatePool();
        uint256 pending = (vault.balanceOf(msg.sender) * accSporePerShare / 1e12) - userRewardDebt[msg.sender];
        
        if (pending > 0) {
            userRewardDebt[msg.sender] = (vault.balanceOf(msg.sender) * accSporePerShare) / 1e12;
            SPORE.transfer(msg.sender, pending);
            emit RewardsClaimed(msg.sender, pending);
        }
    }
} 