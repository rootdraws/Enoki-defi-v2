// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title BannedContractList
* @dev Simple contract for maintaining a blacklist of banned contracts
* 
* Key points:
* - All contracts start approved by default
* - Only owner can ban/approve contracts
* - Uses a simple mapping to track banned status
* - Part of pool interaction permission system
*/

import "@openzeppelin/contracts/access/Ownable.sol";

contract BannedContractList is Initializable, OwnableUpgradeSafe {
   // Maps address to banned status (true = banned, false = approved)
   mapping(address => bool) banned;

   /**
    * @dev Initializes contract and sets up ownership
    */
   function initialize() public initializer {
       __Ownable_init();
   }

   /**
    * @dev Check if contract is approved (not banned)
    */
   function isApproved(address toCheck) external view returns (bool) {
       return !banned[toCheck];
   }

   /**
    * @dev Check if contract is banned
    */
   function isBanned(address toCheck) external view returns (bool) {
       return banned[toCheck];
   }

   /**
    * @dev Remove contract from ban list (owner only)
    */
   function approveContract(address toApprove) external onlyOwner {
       banned[toApprove] = false;
   }

   /**
    * @dev Add contract to ban list (owner only) 
    */
   function banContract(address toBan) external onlyOwner {
       banned[toBan] = true;
   }
}