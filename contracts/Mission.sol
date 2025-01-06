// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title ModernMission
 * @notice Advanced SPORE token distribution controller with enhanced security
 * @dev Manages SPORE token distribution with reentrancy protection and pause functionality
 
 The ModernMission contract is an advanced SPORE token distribution controller. It manages the distribution of SPORE tokens to approved pools, with enhanced security features. Key aspects include:

1. Owner-controlled pool approval and revocation, with optional maximum batch size limits.
2. Approved pools can request SPORE token transfers to specified recipients.
3. Comprehensive tracking of pool-specific and global harvest statistics.
4. Emergency pause and unpause functionality to halt operations if needed.
5. Ability for the owner to rescue stuck tokens (except SPORE) in case of emergencies.
6. Enhanced security with reentrancy protection, input validation, and custom error handling.
7. Comprehensive event emission for pool management and token harvesting.

The contract is designed to be used in conjunction with the SPORE token contract, allowing approved pools to distribute SPORE tokens in a controlled and auditable manner. It provides flexibility for managing multiple pools while ensuring the security and integrity of the token distribution process.
 
 */

contract ModernMission is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Custom errors with descriptive parameters
    error InvalidTokenAddress(address token);
    error InvalidPoolAddress(address pool);
    error PoolAlreadyApproved(address pool);
    error PoolNotApproved(address pool);
    error InvalidRecipient(address recipient);
    error InsufficientBalance(uint256 requested, uint256 available);
    error InvalidAmount();
    error ZeroAddress();

    // Struct for extended pool information
    struct PoolInfo {
        bool isApproved;
        uint256 totalHarvested;
        uint256 lastHarvestTime;
        uint256 harvestCount;    // Added: Track number of harvests
        uint256 maxBatchSize;    // Added: Optional maximum harvest size
    }

    // Core state variables
    IERC20 public immutable sporeToken;
    
    // Enhanced pool tracking with explicit mapping names
    mapping(address pool => PoolInfo info) private _poolRegistry;
    
    // Global harvest tracking
    uint256 private _totalHarvestedSpores;
    uint256 private _globalHarvestCount;

    // Events with comprehensive information
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

    /**
     * @notice Constructor initializes the Mission contract
     * @param _sporeToken Address of the SPORE token contract
     */
    constructor(IERC20 _sporeToken) Ownable(msg.sender) {
        if (address(_sporeToken) == address(0)) revert ZeroAddress();
        sporeToken = _sporeToken;
    }

     /**
     * @notice Check if a pool is approved and get its info
     * @param pool Address of the pool to check
     * @return isApproved Whether the pool is approved
     * @return totalHarvested Total amount harvested by this pool
     * @return lastHarvestTime Timestamp of the last harvest
     * @return harvestCount Number of harvests performed
     * @return maxBatchSize Maximum allowed harvest amount (0 for unlimited)
     */

    function getPoolInfo(address pool) external view returns (
        bool isApproved,
        uint256 totalHarvested,
        uint256 lastHarvestTime,
        uint256 harvestCount,
        uint256 maxBatchSize
    ) {
        PoolInfo memory info = _poolRegistry[pool];
        return (
            info.isApproved,
            info.totalHarvested,
            info.lastHarvestTime,
            info.harvestCount,
            info.maxBatchSize
        );
    }

    /**
     * @notice Allows approved pools to request SPORE transfers
     * @param recipient Address to receive SPORE tokens
     * @param amount Amount of SPORE to transfer
     */
    function sendSpores(
        address recipient,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        // Validate inputs
        if (recipient == address(0)) revert InvalidRecipient(recipient);
        if (amount == 0) revert InvalidAmount();
        
        // Validate pool
        PoolInfo storage poolInfo = _poolRegistry[msg.sender];
        if (!poolInfo.isApproved) revert PoolNotApproved(msg.sender);
        
        // Check batch size limit if set
        if (poolInfo.maxBatchSize > 0 && amount > poolInfo.maxBatchSize) {
            revert InsufficientBalance(amount, poolInfo.maxBatchSize);
        }

        // Check contract balance
        uint256 currentBalance = sporeToken.balanceOf(address(this));
        if (amount > currentBalance) {
            revert InsufficientBalance(amount, currentBalance);
        }

        // Update state before transfer
        unchecked {
            // Safe as these values cannot practically overflow
            poolInfo.totalHarvested += amount;
            poolInfo.harvestCount++;
            _totalHarvestedSpores += amount;
            _globalHarvestCount++;
        }
        
        poolInfo.lastHarvestTime = block.timestamp;

        // Perform transfer
        sporeToken.safeTransfer(recipient, amount);

        emit SporesHarvested(
            msg.sender,
            recipient,
            amount,
            poolInfo.harvestCount,
            block.timestamp
        );
    }

    /**
     * @notice Owner can approve pools to request SPORE
     * @param pool Address of pool to approve
     * @param maxBatchSize Maximum amount per harvest (0 for unlimited)
     */
    function approvePool(
        address pool,
        uint256 maxBatchSize
    ) external onlyOwner {
        if (pool == address(0)) revert ZeroAddress();
        if (_poolRegistry[pool].isApproved) revert PoolAlreadyApproved(pool);
        
        _poolRegistry[pool] = PoolInfo({
            isApproved: true,
            totalHarvested: 0,
            lastHarvestTime: block.timestamp,
            harvestCount: 0,
            maxBatchSize: maxBatchSize
        });

        emit PoolApproved(pool, msg.sender, maxBatchSize, block.timestamp);
    }

    /**
     * @notice Owner can revoke pool approval
     * @param pool Address of pool to revoke
     */
    function revokePool(address pool) external onlyOwner {
        PoolInfo memory poolInfo = _poolRegistry[pool];
        if (!poolInfo.isApproved) revert PoolNotApproved(pool);
        
        uint256 totalHarvested = poolInfo.totalHarvested;
        delete _poolRegistry[pool];
        
        emit PoolRevoked(pool, msg.sender, totalHarvested, block.timestamp);
    }

    /**
     * @notice Update pool's maximum batch size
     * @param pool Pool address to update
     * @param newMaxBatchSize New maximum batch size (0 for unlimited)
     */
    function updatePoolLimit(
        address pool,
        uint256 newMaxBatchSize
    ) external onlyOwner {
        PoolInfo storage poolInfo = _poolRegistry[pool];
        if (!poolInfo.isApproved) revert PoolNotApproved(pool);

        uint256 oldLimit = poolInfo.maxBatchSize;
        poolInfo.maxBatchSize = newMaxBatchSize;

        emit PoolLimitUpdated(pool, oldLimit, newMaxBatchSize, block.timestamp);
    }

    /**
     * @notice Emergency pause of all operations
     */
    function pause() external onlyOwner {
        _pause();
        emit EmergencyAction("PAUSE", address(0), block.timestamp);
    }

    /**
     * @notice Resume operations after pause
     */
    function unpause() external onlyOwner {
        _unpause();
        emit EmergencyAction("UNPAUSE", address(0), block.timestamp);
    }

    /**
     * @notice View functions for contract state
     */
    function getSporeBalance() external view returns (uint256) {
        return sporeToken.balanceOf(address(this));
    }

    function getTotalHarvestedSpores() external view returns (uint256) {
        return _totalHarvestedSpores;
    }

    function getGlobalHarvestCount() external view returns (uint256) {
        return _globalHarvestCount;
    }

    /**
     * @notice Allow owner to rescue stuck tokens (except SPORE)
     * @param token Token to rescue
     * @param amount Amount of tokens to rescue
     * @param recipient Recipient of rescued tokens
     */
    function rescueTokens(
        IERC20 token,
        uint256 amount,
        address recipient
    ) external onlyOwner nonReentrant {
        if (address(token) == address(0) || recipient == address(0)) {
            revert ZeroAddress();
        }
        if (token == sporeToken) revert InvalidTokenAddress(address(token));
        if (amount == 0) revert InvalidAmount();
        
        token.safeTransfer(recipient, amount);
        emit EmergencyAction("RESCUE", address(token), block.timestamp);
    }
}