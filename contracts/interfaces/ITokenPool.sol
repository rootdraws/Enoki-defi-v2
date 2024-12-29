// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

// File Modernized by Claude.AI Sonnet on 12/29/24.

/**
 * @title ITokenPool
 * @notice Interface for managing token pools with rescue functionality
 * @dev Defines core functionality for token pool operations
 */
interface ITokenPool {
    /**
     * @notice Emitted when tokens are transferred from pool
     * @param to Recipient address
     * @param value Amount transferred
     * @param initiator Address that initiated the transfer
     */
    event Transfer(
        address indexed to,
        uint256 value,
        address indexed initiator
    );

    /**
     * @notice Emitted when tokens are rescued from pool
     * @param tokenToRescue Address of token being rescued
     * @param to Recipient address
     * @param amount Amount rescued
     */
    event FundsRescued(
        address indexed tokenToRescue,
        address indexed to,
        uint256 amount
    );

    /**
     * @notice Error thrown when transfer amount exceeds balance
     * @param requested Amount requested
     * @param available Amount available
     */
    error InsufficientPoolBalance(uint256 requested, uint256 available);

    /**
     * @notice Error thrown when rescue operation fails
     * @param token Token address
     * @param reason Failure reason
     */
    error RescueOperationFailed(address token, string reason);

    /**
     * @notice Error thrown for invalid recipient address
     * @param recipient The invalid address
     */
    error InvalidRecipient(address recipient);

    /**
     * @notice Returns the ERC20 token managed by this pool
     * @return IERC20 interface of the managed token
     */
    function token() external view returns (IERC20);

    /**
     * @notice Returns the current token balance of the pool
     * @return Current balance
     */
    function balance() external view returns (uint256);

    /**
     * @notice Transfers tokens from pool to recipient
     * @param to Recipient address
     * @param value Amount to transfer
     * @return success True if transfer succeeds
     */
    function transfer(
        address to,
        uint256 value
    ) external returns (bool success);

    /**
     * @notice Rescues tokens accidentally sent to the pool
     * @param tokenToRescue Address of token to rescue
     * @param to Recipient address
     * @param amount Amount to rescue
     * @return success True if rescue succeeds
     */
    function rescueFunds(
        address tokenToRescue,
        address to,
        uint256 amount
    ) external returns (bool success);
}

/**
 * @title BaseTokenPool
 * @notice Base implementation of token pool functionality
 * @dev Implements common validation and helper functions
 */
abstract contract BaseTokenPool is ITokenPool {
    IERC20 private immutable _token;
    
    /**
     * @notice Constructor sets the managed token
     * @param tokenAddress Address of the ERC20 token
     */
    constructor(address tokenAddress) {
        if (tokenAddress == address(0)) {
            revert InvalidRecipient(tokenAddress);
        }
        _token = IERC20(tokenAddress);
    }

    /// @inheritdoc ITokenPool
    function token() external view override returns (IERC20) {
        return _token;
    }

    /// @inheritdoc ITokenPool
    function balance() external view override returns (uint256) {
        return _token.balanceOf(address(this));
    }

    /**
     * @dev Internal validation for transfers
     */
    function _validateTransfer(
        address to,
        uint256 amount
    ) internal view {
        if (to == address(0)) {
            revert InvalidRecipient(to);
        }
        uint256 currentBalance = _token.balanceOf(address(this));
        if (amount > currentBalance) {
            revert InsufficientPoolBalance(amount, currentBalance);
        }
    }
}