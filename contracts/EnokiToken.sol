// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title ModernEnokiToken
 * @notice Governance token for Enoki DeFi Club with fixed supply and initial distribution
 * @dev Implements EIP-2612 permit and ERC20Votes for gasless approvals and governance
 * 
 * Ecosystem Flow:
 * 1. ENOKI-ETH LP → Stake for SPORE
 * 2. SPORE → Mint Mushroom NFTs 
 * 3. Stake Mushrooms → Earn ENOKI
 * 4. ENOKI → Governance + LP Rewards
 * 
 * Security Features:
 * - Two-step ownership transfers
 * - Reentrancy protection
 * - Zero address checks
 * - Distribution state validation
 
 This is a sophisticated ERC20 governance token for the Enoki DeFi Club with several key features:

Key Characteristics:
- Fixed total supply of 1 million ENOKI tokens
- Fixed distribution across four allocations:
  - 40% Geyser (Mushroom staking rewards)
  - 30% Liquidity Pool
  - 20% DAO Treasury
  - 10% Team/Dev (vested)

Core Features:
1. Governance Capabilities
- ERC20 Votes implementation
- Delegation of voting power
- Signature-based delegation
- Voting power tracking

2. Security Mechanisms
- Two-step ownership transfer
- Reentrancy protection
- Zero address checks
- One-time, immutable token distribution
- Token burning functionality

3. Advanced Token Design
- EIP-2612 permit support
- Nonce management
- Comprehensive event logging

Unique Design Elements:
- Fixed supply with predefined allocation
- Strict initialization process
- Designed for a complex DeFi ecosystem involving staking, NFTs, and governance

The contract provides a robust, feature-rich token designed for decentralized governance and ecosystem participation.
 
 */

contract ModernEnokiToken is 
    ERC20,
    Nonces,
    ERC20Permit, 
    ERC20Votes,
    Ownable2Step, 
    ReentrancyGuard
{
    // Custom errors
    error AlreadyInitialized();
    error ZeroAddress();
    error InsufficientBalance(uint256 requested, uint256 available);
    error NotInitialized();

    // Fixed supply caps with explicit decimal handling
    uint256 public constant TOTAL_SUPPLY = 1_000_000 * 1e18;  // 1 million ENOKI

    // Distribution allocations
    uint256 public constant GEYSER_ALLOCATION = 400_000 * 1e18;   // 40% - Mushroom staking rewards
    uint256 public constant LP_ALLOCATION = 300_000 * 1e18;       // 30% - Initial LP + incentives
    uint256 public constant DAO_ALLOCATION = 200_000 * 1e18;      // 20% - DAO treasury
    uint256 public constant TEAM_ALLOCATION = 100_000 * 1e18;     // 10% - Team/dev (vested)

    // Distribution state
    bool private _initialized;
    
    // Core contracts (immutable for gas optimization)
    address private immutable _geyserContract;
    address private immutable _lpIncentivesContract;
    address private immutable _daoTreasury;
    address private immutable _teamVesting;

    // Events with comprehensive information
    event TokenDistributionCompleted(
        address indexed geyser,
        address indexed lpIncentives,
        address indexed daoTreasury,
        address teamVesting,
        uint256 timestamp
    );

    event TokensBurned(
        address indexed burner,
        uint256 amount,
        uint256 newTotalSupply,
        uint256 timestamp
    );

    event GovernancePowerDelegated(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @notice Initializes the token with distribution addresses
     * @param geyser Mushroom staking rewards contract
     * @param lpIncentives LP incentives contract
     * @param treasury DAO treasury
     * @param team Team vesting contract
     */
    constructor(
        address geyser,
        address lpIncentives,
        address treasury,
        address team
    ) 
        ERC20("Enoki DeFi Club", "ENOKI")
        ERC20Permit("Enoki DeFi Club")
        Ownable(msg.sender)
    {
        // Validate addresses
        if (geyser == address(0) ||
            lpIncentives == address(0) ||
            treasury == address(0) ||
            team == address(0)) revert ZeroAddress();

        _geyserContract = geyser;
        _lpIncentivesContract = lpIncentives;
        _daoTreasury = treasury;
        _teamVesting = team;
    }

    /**
     * @notice One-time distribution of all ENOKI tokens
     * @dev After this, no more tokens can ever be minted
     */
    function initialDistribution() external nonReentrant onlyOwner {
        if (_initialized) revert AlreadyInitialized();
        
        // Distribute all tokens
        _mint(_geyserContract, GEYSER_ALLOCATION);
        _mint(_lpIncentivesContract, LP_ALLOCATION);
        _mint(_daoTreasury, DAO_ALLOCATION);
        _mint(_teamVesting, TEAM_ALLOCATION);

        _initialized = true;

        emit TokenDistributionCompleted(
            _geyserContract,
            _lpIncentivesContract,
            _daoTreasury,
            _teamVesting,
            block.timestamp
        );
    }

    /**
     * @notice Allow token holders to burn tokens
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external nonReentrant {
        if (amount == 0) revert InsufficientBalance(0, 0);
        if (amount > balanceOf(msg.sender)) {
            revert InsufficientBalance(amount, balanceOf(msg.sender));
        }

        _burn(msg.sender, amount);

        emit TokensBurned(
            msg.sender,
            amount,
            totalSupply(),
            block.timestamp
        );
    }

    /**
     * @notice Get current voting power for an account
     * @param account Address to check
     * @return Current vote weight
     */
    function getVotes(
        address account
    ) public view override returns (uint256) {
        return super.getVotes(account);
    }

    /**
     * @notice Delegate voting power with enhanced tracking
     * @param delegatee Address to delegate to
     */
    function delegate(address delegatee) public override {
        if (!_initialized) revert NotInitialized();
        if (delegatee == address(0)) revert ZeroAddress();

        uint256 amount = balanceOf(msg.sender);
        super.delegate(delegatee);

        emit GovernancePowerDelegated(
            msg.sender,
            delegatee,
            amount,
            block.timestamp
        );
    }

    /**
     * @notice Delegate by signature with enhanced tracking
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        if (!_initialized) revert NotInitialized();
        if (delegatee == address(0)) revert ZeroAddress();

        uint256 amount = balanceOf(msg.sender);
        super.delegateBySig(delegatee, nonce, expiry, v, r, s);

        emit GovernancePowerDelegated(
            msg.sender,
            delegatee,
            amount,
            block.timestamp
        );
    }

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
    ) {
        return (
            _geyserContract,
            _lpIncentivesContract,
            _daoTreasury,
            _teamVesting
        );
    }

    /**
     * @notice Check if initial distribution is complete
     */
    function isInitialized() external view returns (bool) {
        return _initialized;
    }

    /**
     * @dev Required override for token transfers when using multiple inheritance
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Votes) {
        super._update(from, to, amount);
    }

    /**
     * @dev Required override for nonces when using multiple inheritance
     */
    function nonces(
        address owner
    ) public view override(Nonces, ERC20Permit) returns (uint256) {
        return Nonces.nonces(owner);
    }
}