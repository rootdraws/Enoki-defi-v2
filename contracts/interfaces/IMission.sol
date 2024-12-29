// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// File Modernized by Claude.AI Sonnet on 12/29/24.

/**
 * @title IMission
 * @notice Interface for managing spore distribution and pool permissions
 * @dev Handles spore transfers and pool authorization
 */
interface IMission {
    /**
     * @notice Emitted when a pool is approved for spore distribution
     * @param pool Address of the approved pool
     * @param approver Address that approved the pool
     */
    event PoolApproved(
        address indexed pool,
        address indexed approver
    );

    /**
     * @notice Emitted when a pool's approval is revoked
     * @param pool Address of the revoked pool
     * @param revoker Address that revoked the pool
     */
    event PoolRevoked(
        address indexed pool,
        address indexed revoker
    );

    /**
     * @notice Error thrown when pool address is invalid
     * @param pool The invalid pool address
     */
    error InvalidPoolAddress(address pool);

    /**
     * @notice Error thrown when spore amount is invalid
     * @param amount The invalid amount
     */
    error InvalidSporeAmount(uint256 amount);

    /**
     * @notice Error thrown when recipient address is invalid
     * @param recipient The invalid recipient address
     */
    error InvalidRecipient(address recipient);

    /**
     * @notice Sends spores to a specified recipient
     * @param recipient Address to receive the spores
     * @param amount Number of spores to send
     * @dev Only callable by approved pools
     */
    function sendSpores(
        address payable recipient,
        uint256 amount
    ) external;

    /**
     * @notice Approves a pool for spore distribution
     * @param pool Address of the pool to approve
     * @dev Only callable by authorized administrators
     */
    function approvePool(address pool) external;

    /**
     * @notice Revokes a pool's approval for spore distribution
     * @param pool Address of the pool to revoke
     * @dev Only callable by authorized administrators
     */
    function revokePool(address pool) external;

    /**
     * @notice Checks if a pool is approved for spore distribution
     * @param pool Address of the pool to check
     * @return bool True if the pool is approved
     */
    function isPoolApproved(address pool) external view returns (bool);
}