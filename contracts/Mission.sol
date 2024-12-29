// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title Mission
* @dev Controls SPORE token distribution to approved pools
* Part of the core economic system for distributing SPORE rewards
* 
* Key Functions:
* - Holds SPORE tokens for distribution
* - Only approved pools can request SPORE transfers
* - Owner can manage pool approval status
*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Mission is Initializable, OwnableUpgradeSafe {

   // Core token and approval state
   IERC20 public sporeToken;                  // The SPORE token being distributed
   mapping (address => bool) public approved;  // Tracks which pools can request SPORE

   // Emitted when pools harvest SPORE tokens
   event SporesHarvested(address pool, uint256 amount);

   /**
    * @dev Restricts function calls to approved pools only
    */
   modifier onlyApprovedPool() {
       require(approved[msg.sender], "Mission: Only approved pools");
       _;
   }

   /**
    * @dev Initializes the contract with SPORE token address
    * @param sporeToken_ Address of the SPORE token contract
    */
   function initialize(IERC20 sporeToken_) public initializer {
       __Ownable_init();
       sporeToken = sporeToken_;
   }

   /**
    * @dev Allows approved pools to request SPORE transfers
    * @param recipient Address to receive SPORE tokens
    * @param amount Amount of SPORE to transfer
    */
   function sendSpores(address recipient, uint256 amount) public onlyApprovedPool {
       sporeToken.transfer(recipient, amount);
       emit SporesHarvested(msg.sender, amount);
   }

   /**
    * @dev Owner can approve pools to request SPORE
    * @param pool Address of pool to approve
    */
   function approvePool(address pool) public onlyOwner {
       approved[pool] = true;
   }

   /**
    * @dev Owner can revoke pool approval
    * @param pool Address of pool to revoke
    */
   function revokePool(address pool) public onlyOwner {
       approved[pool] = false;
   }
}