// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @notice Interface for geyser functionality
 */

interface IEnokiGeyser {
    function getDistributionToken() external view returns (IERC20);
    function lockTokens(uint256 amount, uint256 durationSec) external;
}

// Still has an Error.

/**
 * @title GeyserEscrow
 * @notice Secure token locking mechanism for geyser reward system
 * @dev Enhanced escrow with multi-token support and safety features
 * @custom:security-contact security@example.com
 */

contract GeyserEscrow is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Core state
    IEnokiGeyser public immutable geyser;
    
    /// @notice Token management
    mapping(address => bool) private _allowedRewardTokens;
    mapping(address => uint256) private _totalLocked;
    uint256 private _lastLockTime;

    /// @notice Constants for validation
    uint256 public constant MIN_LOCK_DURATION = 1 days;
    uint256 public constant MAX_LOCK_DURATION = 365 days;
    uint256 public constant MIN_LOCK_AMOUNT = 1e18;    // 1 token minimum
    uint256 public constant LOCK_COOLDOWN = 1 hours;   // Minimum time between locks

    /// @notice Events with detailed information
    event TokensLocked(
        address indexed token,
        uint256 amount,
        uint256 duration,
        uint256 timestamp
    );
    
    event RewardTokenStatusChanged(
        address indexed token,
        bool indexed isAllowed,
        uint256 timestamp
    );
    
    event TokensRecovered(
        address indexed token,
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    /// @dev Custom errors
    error ZeroAddress();
    error InvalidAmount(uint256 provided, uint256 minimum);
    error InvalidDuration(uint256 provided, uint256 minimum, uint256 maximum);
    error TokenNotAllowed(address token);
    error CooldownActive(uint256 remainingTime);
    error LockFailed();
    error ApprovalFailed();
    error NoTokensToRecover();

    /**
     * @notice Sets up the escrow with initial geyser connection
     * @param geyserAddress Address of the geyser contract
     */
    constructor(address geyserAddress) Ownable(msg.sender) {
        if (geyserAddress == address(0)) revert ZeroAddress();
        
        geyser = IEnokiGeyser(geyserAddress);
        
        // Add initial distribution token
        address initialToken = address(geyser.getDistributionToken());
        _allowedRewardTokens[initialToken] = true;
        
        emit RewardTokenStatusChanged(
            initialToken,
            true,
            block.timestamp
        );
    }

    /**
     * @notice Manages reward token allowlist
     * @param tokenAddress Token to modify
     * @param isAllowed Whether to allow or disallow
     */
    function setRewardTokenStatus(
        address tokenAddress,
        bool isAllowed
    ) external onlyOwner {
        if (tokenAddress == address(0)) revert ZeroAddress();
        
        _allowedRewardTokens[tokenAddress] = isAllowed;
        
        emit RewardTokenStatusChanged(
            tokenAddress,
            isAllowed,
            block.timestamp
        );
    }

    /**
     * @notice Checks if a token is allowed
     * @param tokenAddress Token to check
     * @return allowance status
     */
    function isRewardTokenAllowed(
        address tokenAddress
    ) external view returns (bool) {
        return _allowedRewardTokens[tokenAddress];
    }

    /**
     * @notice Lock tokens into the geyser
     * @param amount Amount of tokens to lock
     * @param durationSec Duration of the lock
     */
    function lockTokens(
        uint256 amount,
        uint256 durationSec
    ) external nonReentrant whenNotPaused onlyOwner {
        // Validate inputs
        if (amount < MIN_LOCK_AMOUNT) {
            revert InvalidAmount(amount, MIN_LOCK_AMOUNT);
        }
        if (durationSec < MIN_LOCK_DURATION || durationSec > MAX_LOCK_DURATION) {
            revert InvalidDuration(durationSec, MIN_LOCK_DURATION, MAX_LOCK_DURATION);
        }
        if (block.timestamp < _lastLockTime + LOCK_COOLDOWN) {
            revert CooldownActive(_lastLockTime + LOCK_COOLDOWN - block.timestamp);
        }

        // Get and validate distribution token
        IERC20 distributionToken = geyser.getDistributionToken();
        if (!_allowedRewardTokens[address(distributionToken)]) {
            revert TokenNotAllowed(address(distributionToken));
        }

        // Update state before external calls
        _lastLockTime = block.timestamp;
        _totalLocked[address(distributionToken)] += amount;

        // Execute lock
        // Reset approval to 0 first (safety measure for some tokens)
        distributionToken.approve(address(geyser), 0);
        
        // Execute lock
        distributionToken.approve(address(geyser), amount);
        try geyser.lockTokens(amount, durationSec) {
            emit TokensLocked(
                address(distributionToken),
                amount,
                durationSec,
                block.timestamp
            );
        } catch {
            // Reset approval on failure
            distributionToken.approve(address(geyser), 0);
            revert LockFailed();
        }

     /**
     * @notice Retrieves distribution token information
     * @return token Address of current distribution token
     * @return totalLocked Total amount locked for this token
     * @return lastLockTime Timestamp of last lock operation
     */
 /**
     * @notice Retrieves distribution token information
     * @return token Address of current distribution token
     * @return totalLocked Total amount locked for this token
     * @return lastLockTime Timestamp of last lock operation
     */
    function getDistributionDetails() external view returns (
        address,
        uint256,
        uint256
    ) {
        address token = address(geyser.getDistributionToken());
        uint256 totalLocked = _totalLocked[token];
        return (
            token,
            totalLocked,
            _lastLockTime
        );
    }

    /**
     * @notice Emergency token recovery
     * @param token Token to recover
     * @param recipient Address to receive tokens
     * @param amount Amount to recover
     */
    function recoverTokens(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        if (address(token) == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount(0, 1);

        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert NoTokensToRecover();

        uint256 recoveryAmount = amount > balance ? balance : amount;
        token.safeTransfer(recipient, recoveryAmount);

        emit TokensRecovered(
            address(token),
            recipient,
            recoveryAmount,
            block.timestamp
        );
    }

    /**
     * @notice Pause contract operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause contract operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}