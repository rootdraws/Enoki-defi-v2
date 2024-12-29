// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title EnokiToken
 * @notice Governance token for Enoki DeFi Club with fixed supply and initial distribution
 * 
 * @dev Ecosystem Flow:
 * 1. ENOKI-ETH LP → Stake for SPORE
 * 2. SPORE → Mint Mushroom NFTs 
 * 3. Stake Mushrooms → Earn ENOKI
 * 4. ENOKI → Governance + LP Rewards
 */
contract EnokiToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    // Fixed supply caps
    uint256 public constant TOTAL_SUPPLY = 1_000_000 ether;  // 1 million ENOKI

    // Distribution allocations
    uint256 public constant GEYSER_ALLOCATION = 400_000 ether;   // 40% - Mushroom staking rewards
    uint256 public constant LP_ALLOCATION = 300_000 ether;       // 30% - Initial LP + incentives
    uint256 public constant DAO_ALLOCATION = 200_000 ether;      // 20% - DAO treasury
    uint256 public constant TEAM_ALLOCATION = 100_000 ether;     // 10% - Team/dev (vested)

    // Distribution tracking
    bool private _initialized;
    address private _geyserContract;
    address private _lpIncentivesContract;
    address private _daoTreasury;
    address private _teamVesting;

    // Events
    event TokensDistributed(
        address indexed geyser,
        address indexed lpIncentives,
        address indexed daoTreasury,
        address teamVesting
    );
    event GovernancePowerDelegated(address indexed delegator, address indexed delegatee);

    constructor() 
        ERC20("Enoki DeFi Club", "ENOKI")
        ERC20Permit("Enoki DeFi Club")
        Ownable(msg.sender)
    {
        // No tokens minted in constructor
        // Must call initialDistribution() after setting addresses
    }

    /**
     * @notice One-time distribution of all ENOKI tokens
     * @dev After this, no more tokens can ever be minted
     * 
     * Distribution:
     * - Geyser: For mushroom staking rewards
     * - LP: Initial liquidity and LP incentives
     * - DAO: Protocol treasury and governance
     * - Team: Development funding (vested)
     */
    function initialDistribution(
        address geyser,
        address lpIncentives,
        address treasury,
        address team
    ) external onlyOwner {
        require(!_initialized, "Tokens already distributed");
        require(
            geyser != address(0) && 
            lpIncentives != address(0) && 
            treasury != address(0) && 
            team != address(0), 
            "Invalid address"
        );

        // Store addresses
        _geyserContract = geyser;
        _lpIncentivesContract = lpIncentives;
        _daoTreasury = treasury;
        _teamVesting = team;

        // Distribute all tokens
        _mint(geyser, GEYSER_ALLOCATION);        // For mushroom staking rewards
        _mint(lpIncentives, LP_ALLOCATION);      // For LP and incentives
        _mint(treasury, DAO_ALLOCATION);         // DAO treasury
        _mint(team, TEAM_ALLOCATION);            // Team (vested)

        _initialized = true;

        emit TokensDistributed(geyser, lpIncentives, treasury, team);
    }

    /**
     * @notice Allow token holders to burn tokens
     * @dev Can be used for:
     * - Deflationary mechanics
     * - DAO-voted token burns
     * - LP removals
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Override _beforeTokenTransfer for votes tracking
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Votes) {
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Override _afterTokenTransfer for votes tracking
     */
    function _afterTokenTransfer(
        address from, 
        address to, 
        uint256 amount
    ) internal virtual override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    /**
     * @dev Override supportsInterface for multiple inheritance
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // GOVERNANCE FUNCTIONALITY

    /**
     * @notice Get current voting power for an account
     * @dev Used for:
     * - DAO voting
     * - Rate adjustment voting
     * - Protocol parameter changes
     */
    function getVotes(address account) public view override returns (uint256) {
        return super.getVotes(account);
    }

    /**
     * @notice Get historical voting power at a specific block
     * @dev Required for governance with vote delay
     */
    function getPastVotes(
        address account, 
        uint256 blockNumber
    ) public view override returns (uint256) {
        return super.getPastVotes(account, blockNumber);
    }

    /**
     * @notice Delegate voting power
     * @dev Users must delegate to enable voting power
     * Can delegate to self or another address
     */
    function delegate(address delegatee) public override {
        super.delegate(delegatee);
        emit GovernancePowerDelegated(msg.sender, delegatee);
    }

    /**
     * @notice Delegate by signature
     * @dev Allows gasless delegation
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public override {
        super.delegateBySig(delegatee, nonce, expiry, v, r, s);
        emit GovernancePowerDelegated(msg.sender, delegatee);
    }

    /**
     * @notice Retrieve distribution addresses (if needed)
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
}