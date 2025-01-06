// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// File Modernized by Claude.AI Sonnet on 12/29/24.

/**
 * @title ICamelotFactory
 * @notice Interface for the Camelot Factory contract which manages pair creation and fees
 * @dev This interface modernizes the original Camelot DEX factory interface

This is an interface for a decentralized exchange (DEX) factory contract with advanced pair management capabilities:

Key Features:
- Token pair creation and management
- Flexible fee configuration
- Ownership and referral fee tracking

Core Functionality:
1. Pair Management
- Create token pairs
- Retrieve pair addresses
- Track total number of pairs
- Query pair details

2. Fee Configuration
- Set fee recipient
- Configure owner and referrer fee shares
- Flexible fee allocation

Unique Design Elements:
- Comprehensive event logging for pair creation
- Supports multiple ownership roles
- Detailed fee tracking
- Flexible pair creation mechanism

The interface provides a robust framework for managing liquidity pairs on a decentralized exchange, with sophisticated fee and ownership controls.

 */

interface ICamelotFactory {
    /**
     * @dev Emitted when a new pair is created
     * @param token0 Address of the first token in pair
     * @param token1 Address of the second token in pair
     * @param pair Address of the newly created pair
     * @param pairId Unique identifier for the pair
     */
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256 pairId
    );

    /**
     * @notice Returns the owner address
     */
    function owner() external view returns (address);

    /**
     * @notice Returns the fee percent owner address
     */
    function feePercentOwner() external view returns (address);

    /**
     * @notice Returns the stable owner address
     */
    function setStableOwner() external view returns (address);

    /**
     * @notice Returns the fee recipient address
     */
    function feeTo() external view returns (address);

    /**
     * @notice Returns the owner's share of fees
     * @return Share percentage with precision (e.g., 10000 = 100%)
     */
    function ownerFeeShare() external view returns (uint256);

    /**
     * @notice Returns the referrer's share of fees for a given address
     * @param referrer Address of the referrer
     * @return Share percentage with precision
     */
    function referrersFeeShare(address referrer) external view returns (uint256);

    /**
     * @notice Fetches the pair address for two tokens
     * @param tokenA First token of the pair
     * @param tokenB Second token of the pair
     * @return pair Address of the pair contract, or zero address if it doesn't exist
     */
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    /**
     * @notice Gets a pair from the all pairs array
     * @param index Index in the pairs array
     * @return pair Address of the pair at the given index
     */
    function allPairs(uint256 index) external view returns (address pair);

    /**
     * @notice Returns the total number of pairs created
     * @return Total number of pairs
     */
    function allPairsLength() external view returns (uint256);

    /**
     * @notice Creates a new pair for two tokens
     * @param tokenA First token of the pair
     * @param tokenB Second token of the pair
     * @return pair Address of the newly created pair
     */
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    /**
     * @notice Sets the fee recipient address
     * @param newFeeTo New fee recipient address
     */
    function setFeeTo(address newFeeTo) external;

    /**
     * @notice Returns current fee configuration
     * @return _ownerFeeShare Current owner fee share
     * @return _feeTo Current fee recipient address
     */
    function feeInfo() external view returns (
        uint256 _ownerFeeShare,
        address _feeTo
    );
}