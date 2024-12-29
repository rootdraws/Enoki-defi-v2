// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BannedContractList.sol";

/**
 * @title Defensible
 * @notice Provides protection against unauthorized contract interactions
 * @dev Implements a modifier to block calls from unapproved contracts
 * 
 * Key features:
 * - Single modifier that can be applied to any function
 * - Only affects contract callers (not EOA users)
 * - Uses BannedContractList for contract approval checks
 */
abstract contract Defensible {
    /**
     * @notice Modifier to block calls from unapproved contracts
     * @dev Allows direct EOA calls or approved contract calls
     * @param bannedContractList The contract managing approved/banned contract list
     */
    modifier defend(BannedContractList bannedContractList) {
        _checkDefensibleConditions(bannedContractList);
        _;
    }

    /**
     * @dev Internal function to perform defensible checks
     * @param bannedContractList The contract managing approved/banned contract list
     */
    function _checkDefensibleConditions(BannedContractList bannedContractList) internal view {
        // Allow calls directly from EOA (Externally Owned Accounts)
        // Or calls from explicitly approved contracts
        require(
            msg.sender == tx.origin || bannedContractList.isApproved(msg.sender),
            "Defensible: Unapproved contract call"
        );
    }
}