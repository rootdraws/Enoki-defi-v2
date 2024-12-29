// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title Defensible
* @dev Helper contract that provides protection against unapproved contract interactions
* 
* Key features:
* - Single modifier that can be applied to any function
* - Only affects contract callers (not EOA users)
* - Uses BannedContractList for checks
*/

import "./BannedContractList.sol";

contract Defensible {
   /**
    * @dev Modifier that blocks calls from unapproved contracts
    * tx.origin == msg.sender -> EOA call (always allowed)
    * tx.origin != msg.sender -> Contract call (must be approved)
    */
   modifier defend(BannedContractList bannedContractList) {
       require(
           (msg.sender == tx.origin) || bannedContractList.isApproved(msg.sender),
           "This smart contract has not been approved"
       );
       _;
   }
}