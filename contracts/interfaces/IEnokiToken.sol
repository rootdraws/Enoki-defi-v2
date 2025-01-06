// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title IEnokiToken
 * @notice Interface for Enoki governance token with initial supply distribution and voting
 * @dev Extends standard ERC20 with voting, permit, and distribution features
 */

interface IEnokiToken is IERC20, IERC20Permit, IVotes {
    // Custom errors
    error AlreadyInitialized();
    error ZeroAddress();
    error InsufficientBalance(uint256 requested, uint256 available);
    error NotInitialized();

    /**
     * @notice Emitted when initial token distribution is completed
     */
    event TokenDistributionCompleted(
        address indexed geyser,
        address indexed lpIncentives,
        address indexed daoTreasury,
        address teamVesting,
        uint256 timestamp
    );

    /**
     * @notice Emitted when tokens are burned
     */
    event TokensBurned(
        address indexed burner,
        uint256 amount,
        uint256 newTotalSupply,
        uint256 timestamp
    );

    /**
     * @notice Emitted when governance power is delegated
     */
    event GovernancePowerDelegated(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount,
        uint256 timestamp
    );

    // Supply constants
    function TOTAL_SUPPLY() external view returns (uint256);
    function GEYSER_ALLOCATION() external view returns (uint256);
    function LP_ALLOCATION() external view returns (uint256);
    function DAO_ALLOCATION() external view returns (uint256);
    function TEAM_ALLOCATION() external view returns (uint256);

    /**
     * @notice Performs one-time distribution of all tokens
     */
    function initialDistribution() external;

    /**
     * @notice Burns specified amount of caller's tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external;

    /**
     * @notice Get all distribution addresses
     * @return geyser Address of the mushroom staking rewards contract
     * @return lpIncentives Address of the LP incentives contract
     * @return daoTreasury Address of the DAO treasury
     * @return teamVesting Address of the team vesting contract
     */
    function getDistributionAddresses() external view returns (
        address geyser,
        address lpIncentives,
        address daoTreasury,
        address teamVesting
    );

    /**
     * @notice Checks if initial distribution is complete
     * @return True if distribution has been completed
     */
    function isInitialized() external view returns (bool);
}