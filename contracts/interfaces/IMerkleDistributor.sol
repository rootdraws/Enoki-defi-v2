// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title IModernMerkleDistributor
 * @notice Interface for advanced token distribution system using Merkle proofs
 
 This is a sophisticated interface for a token distribution system leveraging Merkle tree proofs:

Key Features:
- Secure, verifiable token claims
- Merkle proof-based distribution
- Flexible claim mechanism

Core Functionality:
1. Token Distribution
- Claim tokens with Merkle proofs
- Track claim status
- Support tiered claiming with optional tips
- DAO token recovery

2. Security Mechanisms
- Comprehensive error handling
- Claim verification
- Pausable distribution
- Dust collection
- Time-based release controls

Unique Design Elements:
- Cryptographically secure claim verification
- Detailed claim tracking
- Emergency action support
- Flexible claim percentage
- Support for ETH and token balances

The interface provides a robust, flexible framework for complex, secure token distribution with multiple safety and governance features.
 
 */

interface IModernMerkleDistributor {
    // Structs
    struct ClaimInfo {
        bool claimed;
        uint256 amount;
        uint256 timestamp;
        address claimer;
    }

    // Events
    event TokensClaimed(
        uint256 indexed index,
        address indexed recipient,
        address indexed claimer,
        uint256 claimedAmount,
        uint256 tipAmount,
        uint256 timestamp
    );

    event UnclaimedTokensTransferred(
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    event DustCollected(
        address indexed collector,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    event EmergencyAction(
        string indexed action,
        address indexed initiator,
        uint256 timestamp
    );

    // Errors
    error InvalidAddress(address providedAddress);
    error ClaimAlreadyProcessed(uint256 index, address claimer);
    error InvalidClaimProof(uint256 index, address recipient, uint256 amount);
    error InvalidTipPercentage(uint256 provided, uint256 maximum);
    error ReleaseTimeNotReached(uint256 current, uint256 required);
    error ProtectedTokenTransfer(address token);
    error InsufficientBalance(uint256 requested, uint256 available);
    error ZeroAmount();
    error InvalidMerkleRoot();

    // View Functions
    function distributionToken() external view returns (IERC20);
    function merkleRoot() external view returns (bytes32);
    function daoTreasury() external view returns (address);
    function daoReleaseTime() external view returns (uint256);
    function totalClaimed() external view returns (uint256);
    function totalClaims() external view returns (uint256);
    function getClaimInfo(uint256 index) external view returns (
        bool claimed,
        uint256 amount,
        uint256 timestamp,
        address claimer
    );
    function isClaimed(uint256 index) external view returns (bool);
    function getDistributionTokenBalance() external view returns (uint256);
    function getEthBalance() external view returns (uint256);

    // State-Changing Functions
    function claim(
        uint256 index,
        address recipient,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint256 tipPercentage
    ) external;

    function transferUnclaimedToDao() external;
    function pause() external;
    function unpause() external;
    function collectDust(
        address tokenAddress,
        uint256 amount
    ) external;

    // Special Function
    receive() external payable;
}