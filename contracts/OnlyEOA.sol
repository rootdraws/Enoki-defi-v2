// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title OnlyEOA
* @dev Security contract that restricts function calls to Externally Owned Accounts only
* Prevents smart contracts from interacting with protected functions
* 
* Security Note:
* - Simple but effective anti-contract measure
* - Does not protect against all attack vectors
* - Should be used alongside other security measures
*/

contract OnlyEOA {
   /**
    * @dev Modifier that only allows EOA addresses to call functions
    * Uses msg.sender == tx.origin check to identify EOAs
    * 
    * How it works:
    * - msg.sender: immediate caller of function
    * - tx.origin: original EOA that started transaction
    * - If they match = EOA call
    * - If they don't match = contract call
    */
   modifier onlyEOA {
       require(
           (msg.sender == tx.origin), 
           "Only EOAs can call"
       );
       _;
   }
}