// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @notice Interface for geyser functionality
 */
interface IEnokiGeyser {
    function getDistributionToken() external view returns (IERC20);
    function lockTokens(uint256 amount, uint256 durationSec) external;
}

/**
 * @title GeyserEscrow
 * @notice Secure token locking mechanism for geyser reward system
 * @dev Enhanced escrow with multi-token support and safety features
 * @custom:security-contact security@example.com
 */
contract GeyserEscrow is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /// @notice Core state
    IEnokiGeyser public immutable geyser;
    
    /// @notice Token management
    mapping(address token => bool allowed) private _allowedRewardTokens;
    mapping(address token => uint256 amount) private _totalLocked;
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
        uint256 lockTime,
        uint256 unlockTime
    );
    
    event RewardTokenStatusChanged(
        address indexed token,
        bool indexed isAllowed,
        address indexed operator,
        uint256 timestamp
    );
    
    event TokensRecovered(
        address indexed token,
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    event EmergencyAction(
        string indexed action,
        address indexed initiator,
        uint256 timestamp
    );

    /// @dev Custom errors with descriptive parameters
    error ZeroAddress();
    error InvalidAmount(uint256 provided, uint256 minimum);
    error InvalidDuration(uint256 provided, uint256 minimum, uint256 maximum);
    error TokenNotAllowed(address token);
    error CooldownActive(uint256 currentTime, uint256 nextValidTime);
    error LockFailed(address token, uint256 amount);
    error ApprovalFailed(address token, uint256 amount);
    error NoTokensToRecover(address token);
    error InsufficientBalance(uint256 requested, uint256 available);

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
            msg.sender,
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
            msg.sender,
            block.timestamp
        );
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
        
        uint256 nextValidLockTime = _lastLockTime + LOCK_COOLDOWN;
        if (block.timestamp < nextValidLockTime) {
            revert CooldownActive(block.timestamp, nextValidLockTime);
        }

        // Get and validate distribution token
        IERC20 distributionToken = geyser.getDistributionToken();
        address tokenAddress = address(distributionToken);
        
        if (!_allowedRewardTokens[tokenAddress]) {
            revert TokenNotAllowed(tokenAddress);
        }

        // Validate balance
        uint256 balance = distributionToken.balanceOf(address(this));
        if (amount > balance) {
            revert InsufficientBalance(amount, balance);
        }

        // Update state before external calls
        _lastLockTime = block.timestamp;
        unchecked {
            // Safe because we checked balance above
            _totalLocked[tokenAddress] += amount;
        }

        // Reset approval first (safety measure for some tokens)
        distributionToken.approve(address(geyser), 0);
        distributionToken.approve(address(geyser), amount);

        // Execute lock
        try geyser.lockTokens(amount, durationSec) {
            emit TokensLocked(
                tokenAddress,
                amount,
                durationSec,
                block.timestamp,
                block.timestamp + durationSec
            );
        } catch {
            // Reset approval and state on failure
            distributionToken.approve(address(geyser), 0);
            _totalLocked[tokenAddress] -= amount;
            revert LockFailed(tokenAddress, amount);
        }
    }

    /**
     * @notice Retrieves distribution token information
     * @return token Address of current distribution token
     * @return totalLocked Total amount locked for this token
     * @return lastLockTime Timestamp of last lock operation
     */
    function getDistributionDetails() external view returns (address, uint256, uint256) {
        address token = address(geyser.getDistributionToken());
        uint256 totalLocked = _totalLocked[token];
        return (token, totalLocked, _lastLockTime);
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
    ) external onlyOwner nonReentrant {
        if (address(token) == address(0)) revert ZeroAddress();
        if (recipient == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount(0, 1);

        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert NoTokensToRecover(address(token));
        if (amount > balance) revert InsufficientBalance(amount, balance);

        token.safeTransfer(recipient, amount);

        emit TokensRecovered(
            address(token),
            recipient,
            amount,
            block.timestamp
        );
    }

    /**
     * @notice View functions
     */
    function isRewardTokenAllowed(address token) external view returns (bool) {
        return _allowedRewardTokens[token];
    }

    function getTokenBalance(IERC20 token) external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @notice Emergency functions
     */
    function pause() external onlyOwner {
        _pause();
        emit EmergencyAction("PAUSE", msg.sender, block.timestamp);
    }

    function unpause() external onlyOwner {
        _unpause();
        emit EmergencyAction("UNPAUSE", msg.sender, block.timestamp);
    }
}