// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// File Modernized by Claude.AI Sonnet on 12/29/24.

/**
 * @title IRateVoteable
 * @notice Interface for contracts with rate adjustment functionality
 * @dev Allows authorized parties to modify rates through voting
 */
interface IRateVoteable {
    /**
     * @notice Emitted when the rate is changed
     * @param percentage New rate percentage
     * @param previousPercentage Previous rate percentage
     * @param changedBy Address that initiated the rate change
     */
    event RateChanged(
        uint256 indexed percentage,
        uint256 indexed previousPercentage,
        address indexed changedBy
    );

    /**
     * @notice Error thrown when rate percentage is invalid
     * @param percentage The invalid percentage value
     */
    error InvalidRatePercentage(uint256 percentage);

    /**
     * @notice Error thrown when caller is not authorized to change rate
     * @param caller Address attempting the change
     */
    error UnauthorizedRateChange(address caller);

    /**
     * @notice Changes the current rate percentage
     * @param percentage New rate percentage value
     * @dev Reverts if percentage is invalid or caller is unauthorized
     */
    function changeRate(uint256 percentage) external;

    /**
     * @notice Returns the current rate percentage
     * @return Current rate value
     */
    function getCurrentRate() external view returns (uint256);

    /**
     * @notice Returns the maximum allowed rate percentage
     * @return Maximum rate value
     */
    function getMaxRate() external view returns (uint256);
}