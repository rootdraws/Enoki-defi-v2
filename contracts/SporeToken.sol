// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title SporeToken
* @dev SPORE ERC20 token with controlled minting and initial transfer restrictions
* 
* Key Features:
* - Transfer restrictions until liquidity is added
* - Controlled minting rights
* - Burnable by holders
* - Initial liquidity management system
*
* DAO Owned LP Considerations:
* - Initial LP tokens minted to DAO treasury
* - LP fees accrue to DAO 
* - DAO can adjust liquidity depth based on market conditions
* - No need for LP locking as DAO controls liquidity
* 
* LP Fee Collection Strategy:
* - Collect fees periodically through DAO vote
* - Can compound fees back into LP
* - Can use fees for protocol development
* - Can distribute fees to stakers/holders
* 
* LP Incentives Possibilities:
* - Yield farming rewards for LP providers
* - Bonus emissions for longer-term LPs
* - Vote weight multipliers for LP stakers
* - Revenue share for strategic LPs

SPORE Token
├── ERC20 Implementation
├── Controlled minting rights
├── Transfer restrictions for launch
└── Burning mechanics

*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SporeToken is ERC20("SporeFinance", "SPORE"), Ownable {

   /* ========== STATE VARIABLES ========== */
   mapping(address => bool) public minters;           // Addresses allowed to mint
   address public initialLiquidityManager;           // Controls initial liquidity setup

   bool internal _transfersEnabled;                  // Global transfer switch
   mapping(address => bool) internal _canTransferInitialLiquidity;  // Early transfer permissions

   /**
    * @dev Sets up token with initial liquidity manager
    * Transfers disabled by default until liquidity setup
    * 
    * For DAO LP Setup:
    * - Create initial LP position
    * - LP tokens to DAO treasury
    * - Set up fee collection mechanism
    * - Initialize incentive structures
    */
   constructor(address initialLiquidityManager_) public {
       _transfersEnabled = false;
       minters[msg.sender] = true;
       initialLiquidityManager = initialLiquidityManager_;
       _canTransferInitialLiquidity[msg.sender] = true;
   }

   /* ========== MUTATIVE FUNCTIONS ========== */

   /**
    * @dev Modified transfer to enforce transfer restrictions
    * Only allowed if:
    * - Global transfers enabled OR
    * - Sender has initial liquidity transfer rights
    */
   function transfer(address recipient, uint256 amount) public override returns (bool) {
       require(_transfersEnabled || _canTransferInitialLiquidity[msg.sender], "SporeToken: transfers not enabled");
       return super.transfer(recipient, amount);
   }

   /**
    * @dev Modified transferFrom with same restrictions as transfer
    */
   function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
       require(_transfersEnabled || _canTransferInitialLiquidity[msg.sender], "SporeToken: transfers not enabled");
       return super.transferFrom(sender, recipient, amount);
   }

   /**
    * @dev Allow any holder to burn their tokens
    * Could be used for:
    * - Deflationary mechanics
    * - Token redemption
    * - Removing excess supply
    */
   function burn(uint256 amount) public {
       require(amount > 0);
       require(balanceOf(msg.sender) >= amount);
       _burn(msg.sender, amount);
   }

   /* ========== RESTRICTED FUNCTIONS ========== */

   /**
    * @dev Mint new tokens (only callable by minters)
    * Used for:
    * - Initial distribution
    * - Rewards/emissions
    * - Protocol-controlled minting 
    */
   function mint(address to, uint256 amount) public onlyMinter {
       _mint(to, amount);
   }

   /**
    * @dev Grant initial transfer rights before public launch
    * Used to set up:
    * - Initial LP
    * - Protocol reserves
    * - Early distributions
    */
   function addInitialLiquidityTransferRights(address account) public onlyInitialLiquidityManager {
       require(!_transfersEnabled, "SporeToken: cannot add initial liquidity transfer rights after global transfers enabled");
       _canTransferInitialLiquidity[account] = true;
   }

   /**
    * @dev Enable public transfers - one time operation
    * Typically called after:
    * - Initial LP is set
    * - Protocol is ready for public trading
    */
   function enableTransfers() public onlyInitialLiquidityManager {
       _transfersEnabled = true;
   }

   /**
    * @dev Minter management functions
    * Controls who can mint new tokens
    */
   function addMinter(address account) public onlyOwner {
       minters[account] = true;
   }

   function removeMinter(address account) public onlyOwner {
       minters[account] = false;
   }

   // Access control modifiers
   modifier onlyMinter() {
       require(minters[msg.sender], "Restricted to minters.");
       _;
   }

   modifier onlyInitialLiquidityManager() {
       require(initialLiquidityManager == msg.sender, "Restricted to initial liquidity manager.");
       _;
   }
}