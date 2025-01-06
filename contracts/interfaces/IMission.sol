// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title IModernMission
 * @notice Interface for advanced SPORE token distribution controller
 */

interface IModernMission {
    // Structs
    struct PoolInfo {
        bool isApproved;
        uint256 totalHarvested;
        uint256 lastHarvestTime;
        uint256 harvestCount;
        uint256 maxBatchSize;
    }

    // Events
    event PoolApproved(
        address indexed pool,
        address indexed approver,
        uint256 maxBatchSize,
        uint256 timestamp
    );

    event PoolRevoked(
        address indexed pool,
        address indexed revoker,
        uint256 totalHarvested,
        uint256 timestamp
    );

    event SporesHarvested(
        address indexed pool,
        address indexed recipient,
        uint256 amount,
        uint256 harvestCount,
        uint256 timestamp
    );

    event PoolLimitUpdated(
        address indexed pool,
        uint256 oldLimit,
        uint256 newLimit,
        uint256 timestamp
    );

    event EmergencyAction(
        string indexed action,
        address indexed target,
        uint256 timestamp
    );

    // Errors
    error InvalidTokenAddress(address token);
    error InvalidPoolAddress(address pool);
    error PoolAlreadyApproved(address pool);
    error PoolNotApproved(address pool);
    error InvalidRecipient(address recipient);
    error InsufficientBalance(uint256 requested, uint256 available);
    error InvalidAmount();
    error ZeroAddress();

    // View Functions
    function sporeToken() external view returns (IERC20);
    function getPoolInfo(address pool) external view returns (
        bool isApproved,
        uint256 totalHarvested,
        uint256 lastHarvestTime,
        uint256 harvestCount,
        uint256 maxBatchSize
    );
    function getSporeBalance() external view returns (uint256);
    function getTotalHarvestedSpores() external view returns (uint256);
    function getGlobalHarvestCount() external view returns (uint256);

    // State-Changing Functions
    function sendSpores(
        address recipient,
        uint256 amount
    ) external;

    function approvePool(
        address pool,
        uint256 maxBatchSize
    ) external;

    function revokePool(address pool) external;

    function updatePoolLimit(
        address pool,
        uint256 newMaxBatchSize
    ) external;

    function pause() external;
    function unpause() external;
    
    function rescueTokens(
        IERC20 token,
        uint256 amount,
        address recipient
    ) external;
}