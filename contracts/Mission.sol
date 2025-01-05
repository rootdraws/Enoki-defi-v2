// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title ModernMission
 * @notice Advanced SPORE token distribution controller
 * @dev Manages SPORE token distribution with enhanced security and flexibility
 * 
 * Core Features:
 * - Secure SPORE token distribution
 * - Granular pool access control
 * - Enhanced ownership management
 * - Comprehensive event tracking
 */
contract ModernMission is Ownable2Step {
    using SafeERC20 for IERC20;

    // Custom error types for gas-efficient error handling
    error InvalidTokenAddress();
    error InvalidPoolAddress();
    error PoolAlreadyApproved();
    error PoolNotApproved();
    error InvalidRecipient();
    error InsufficientBalance();

    // Struct for extended pool information
    struct PoolInfo {
        bool isApproved;
        uint256 totalHarvested;
        uint256 lastHarvestTime;
    }

    // Core state variables
    IERC20 public immutable sporeToken;
    
    // Enhanced pool tracking
    mapping(address => PoolInfo) private _poolRegistry;
    
    // Global harvest tracking
    uint256 private _totalHarvestedSpores;

    // Events with comprehensive information
    event PoolApproved(
        address indexed pool, 
        address indexed approver, 
        uint256 timestamp
    );
    event PoolRevoked(
        address indexed pool, 
        address indexed revoker, 
        uint256 timestamp
    );
    event SporesHarvested(
        address indexed pool, 
        address indexed recipient, 
        uint256 amount, 
        uint256 timestamp
    );

    /**
     * @notice Constructor initializes the Mission contract
     * @param _sporeToken Address of the SPORE token contract
     */
    constructor(IERC20 _sporeToken) Ownable2Step() {
        if (address(_sporeToken) == address(0)) revert InvalidTokenAddress();
        sporeToken = _sporeToken;
    }

    /**
     * @notice Check if a pool is approved
     * @param pool Address of the pool to check
     * @return Pool approval status and additional details
     */
    function getPoolInfo(address pool) external view returns (PoolInfo memory) {
        return _poolRegistry[pool];
    }

    /**
     * @notice Allows approved pools to request SPORE transfers
     * @param recipient Address to receive SPORE tokens
     * @param amount Amount of SPORE to transfer
     */
    function sendSpores(address recipient, uint256 amount) external {
        // Validate pool and recipient
        PoolInfo storage poolInfo = _poolRegistry[msg.sender];
        if (!poolInfo.isApproved) revert PoolNotApproved();
        if (recipient == address(0)) revert InvalidRecipient();
        
        // Check contract balance
        uint256 currentBalance = sporeToken.balanceOf(address(this));
        if (amount > currentBalance) revert InsufficientBalance();

        // Update pool and global harvest tracking
        poolInfo.totalHarvested += amount;
        poolInfo.lastHarvestTime = block.timestamp;
        _totalHarvestedSpores += amount;

        // Perform token transfer
        sporeToken.safeTransfer(recipient, amount);

        emit SporesHarvested(msg.sender, recipient, amount, block.timestamp);
    }

    /**
     * @notice Owner can approve pools to request SPORE
     * @param pool Address of pool to approve
     * @param initialAllowance Optional initial harvest allowance
     */
    function approvePool(address pool, uint256 initialAllowance) external onlyOwner {
        if (pool == address(0)) revert InvalidPoolAddress();
        if (_poolRegistry[pool].isApproved) revert PoolAlreadyApproved();
        
        _poolRegistry[pool] = PoolInfo({
            isApproved: true,
            totalHarvested: 0,
            lastHarvestTime: block.timestamp
        });

        emit PoolApproved(pool, msg.sender, block.timestamp);
    }

    /**
     * @notice Owner can revoke pool approval
     * @param pool Address of pool to revoke
     */
    function revokePool(address pool) external onlyOwner {
        if (!_poolRegistry[pool].isApproved) revert PoolNotApproved();
        
        delete _poolRegistry[pool];
        emit PoolRevoked(pool, msg.sender, block.timestamp);
    }

    /**
     * @notice Retrieve the contract's SPORE token balance
     * @return Current SPORE token balance
     */
    function getSporeBalance() external view returns (uint256) {
        return sporeToken.balanceOf(address(this));
    }

    /**
     * @notice Get total SPORE tokens harvested across all pools
     * @return Total harvested SPORE tokens
     */
    function getTotalHarvestedSpores() external view returns (uint256) {
        return _totalHarvestedSpores;
    }

    /**
     * @notice Allow owner to rescue stuck tokens
     * @param token Token to rescue
     * @param amount Amount of tokens to rescue
     * @param recipient Recipient of rescued tokens
     */
    function rescueTokens(
        IERC20 token, 
        uint256 amount, 
        address recipient
    ) external onlyOwner {
        // Prevent rescuing the SPORE token
        if (token == sporeToken) revert InvalidTokenAddress();
        
        token.safeTransfer(recipient, amount);
    }
}