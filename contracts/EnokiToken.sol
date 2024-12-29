// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title ENOKI Token
* @dev Governance token for Enoki DeFi Club with fixed supply and initial distribution
*
* Ecosystem Flow:
* 1. ENOKI-ETH LP → Stake for SPORE
* 2. SPORE → Mint Mushroom NFTs 
* 3. Stake Mushrooms → Earn ENOKI
* 4. ENOKI → Governance + LP Rewards
*/

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract EnokiToken is ERC20Votes, Ownable, Pausable {
   // Fixed supply caps
   uint256 public constant TOTAL_SUPPLY = 1_000_000 ether;  // 1 million ENOKI

   // Distribution allocations
   uint256 public constant GEYSER_ALLOCATION = 400_000 ether;   // 40% - Mushroom staking rewards
   uint256 public constant LP_ALLOCATION = 300_000 ether;       // 30% - Initial LP + incentives
   uint256 public constant DAO_ALLOCATION = 200_000 ether;      // 20% - DAO treasury
   uint256 public constant TEAM_ALLOCATION = 100_000 ether;     // 10% - Team/dev (vested)

   // Distribution tracking
   bool public initialized;
   address public geyserContract;
   address public lpIncentivesContract;
   address public daoTreasury;
   address public teamVesting;

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
       ERC20Permit("Enoki DeFi Club")  // Required by ERC20Votes
   {
       // No tokens minted in constructor
       // Must call initialDistribution() after setting addresses
   }

   /**
    * @dev One-time distribution of all ENOKI tokens
    * After this, no more tokens can ever be minted
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
       require(!initialized, "Already distributed");
       require(geyser != address(0) && lpIncentives != address(0) && 
               treasury != address(0) && team != address(0), "Zero address");

       // Store addresses
       geyserContract = geyser;
       lpIncentivesContract = lpIncentives;
       daoTreasury = treasury;
       teamVesting = team;

       // Distribute all tokens
       _mint(geyser, GEYSER_ALLOCATION);        // For mushroom staking rewards
       _mint(lpIncentives, LP_ALLOCATION);      // For LP and incentives
       _mint(treasury, DAO_ALLOCATION);         // DAO treasury
       _mint(team, TEAM_ALLOCATION);            // Team (vested)

       initialized = true;

       emit TokensDistributed(geyser, lpIncentives, treasury, team);
   }

   /**
    * @dev Allow token holders to burn
    * Could be used for:
    * - Deflationary mechanics
    * - DAO-voted token burns
    * - LP removals
    */
   function burn(uint256 amount) external {
       _burn(msg.sender, amount);
   }

   /**
    * @dev Pause all token transfers
    * Emergency use only
    */
   function pause() external onlyOwner {
       _pause();
   }

   function unpause() external onlyOwner {
       _unpause();
   }

   /**
    * @dev Hook called before any transfer
    * Adds pausable functionality
    */
   function _beforeTokenTransfer(
       address from,
       address to,
       uint256 amount
   ) internal virtual override whenNotPaused {
       super._beforeTokenTransfer(from, to, amount);
   }

   // GOVERNANCE FUNCTIONALITY

   /**
    * @dev Get current voting power
    * Used by:
    * - DAO voting
    * - Rate adjustment voting
    * - Protocol parameter changes
    */
   function getVotes(address account) public view override returns (uint256) {
       return super.getVotes(account);
   }

   /**
    * @dev Get historical voting power
    * Required for governance with vote delay
    */
   function getPastVotes(
       address account, 
       uint256 blockNumber
   ) public view override returns (uint256) {
       return super.getPastVotes(account, blockNumber);
   }

   /**
    * @dev Delegate voting power
    * Users must delegate to enable voting power
    * Can delegate to self or another address
    */
   function delegate(address delegatee) public override {
       super.delegate(delegatee);
       emit GovernancePowerDelegated(msg.sender, delegatee);
   }

   /**
    * @dev Delegate by signature
    * Allows gasless delegation
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
}