// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title TokenPool
* @dev Simple contract to hold and manage separate pools of tokens
* 
* Key Features:
* - Isolated token pools
* - Owner-controlled transfers
* - Emergency rescue function for wrong tokens
* - Upgradeable pattern
*
* Think of it like separate bank accounts:
* - Each TokenPool is like a separate account
* - Can deploy multiple pools for different purposes:
*   - Staking rewards pool
*   - Airdrop distribution pool
*   - Team vesting pool
*   - Treasury reserve pool
* - Better than single contract with complex accounting
* - Reduces risk through isolation
*
* Use Cases:
* - Managing different reward pools separately
* - Isolating protocol reserves
* - Separate vesting/distribution pools
* - Organized treasury management
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenPool is Initializable, OwnableUpgradeSafe {
   IERC20 public token;  // Main token being pooled

   /**
    * @dev Initializes pool with specific token
    * Uses upgradeable pattern instead of constructor
    * Each pool instance handles one token type
    */
   function initialize(IERC20 _token) public initializer {
       __Ownable_init();
       token = _token;
   }

   /**
    * @dev Get current token balance of this specific pool
    * Useful for monitoring individual pool balances
    */
   function balance() public view returns (uint256) {
       return token.balanceOf(address(this));
   }

   /**
    * @dev Owner can transfer tokens from this specific pool
    * Each pool's transfers are independent of other pools
    * @param to Recipient address
    * @param value Amount to transfer from this pool
    */
   function transfer(address to, uint256 value) external onlyOwner returns (bool) {
       return token.transfer(to, value);
   }

   /**
    * @dev Emergency function to rescue wrong tokens sent to this pool
    * Cannot rescue the main pooled token
    * Keeps each pool's primary token secure while allowing recovery of mistakes
    * @param tokenToRescue Address of token to rescue
    * @param to Recipient of rescued tokens
    * @param amount Amount to rescue
    */
   function rescueFunds(address tokenToRescue, address to, uint256 amount) external onlyOwner returns (bool) {
       require(address(token) != tokenToRescue, 'TokenPool: Cannot claim token held by the contract');
       return IERC20(tokenToRescue).transfer(to, amount);
   }
}