// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title ITokenPool
 * @notice Interface for managing upgradeable token pools with enhanced security
 * @dev Implements initializable pattern for proxy deployment
 
This is an interface defining a flexible, secure token pool management system:

Key Features:
- Initializable token pool contract
- Supports single token management
- Enhanced security mechanisms

Core Functionality:
1. Token Operations
- Initialize pool with specific token
- Transfer tokens from pool
- Query pool balance
- Rescue accidentally sent tokens

2. Security Mechanisms
- Zero-address checks
- Prevents rescuing pool's native token
- Comprehensive error handling

Unique Design Elements:
- Upgradeable proxy support
- Event logging for all significant actions
- Standardized token pool management interface
- Flexible fund transfer and rescue capabilities

The interface provides a robust, reusable pattern for creating token pools with built-in safety checks and management capabilities.
 
 */

interface ITokenPool {
    /**
     * @notice Emitted when tokens are transferred from pool
     * @param to Recipient address
     * @param amount Amount transferred
     */
    event TokensTransferred(
        address indexed to,
        uint256 amount
    );

    /**
     * @notice Emitted when wrong tokens are rescued from pool
     * @param token Address of token being rescued
     * @param to Recipient address
     * @param amount Amount rescued
     */
    event TokensRescued(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    // Custom Errors
    error CannotRescuePoolToken();
    error ZeroAddress();
    error ZeroAmount();

    /**
     * @notice Initializes the pool with a specific token
     * @param _token Address of the token to be pooled
     */
    function initialize(IERC20 _token) external;

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
     * @param amount Amount to transfer
     */
    function transfer(
        address to,
        uint256 amount
    ) external;

    /**
     * @notice Rescues tokens accidentally sent to the pool
     * @param tokenToRescue Token to rescue
     * @param to Recipient address
     * @param amount Amount to rescue
     */
    function rescueFunds(
        IERC20 tokenToRescue,
        address to,
        uint256 amount
    ) external;
}