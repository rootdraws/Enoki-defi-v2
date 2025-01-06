// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BannedContractList} from "./BannedContractList.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title Defensible
 * @notice Lightweight security contract to protect against unauthorized contract interactions
 
 This is a lightweight security contract designed to prevent unauthorized contract interactions:

Key Features:
- Implements a defense modifier for contract calls
- Blocks interactions from unauthorized contracts
- Uses a banned contract list for validation

Core Security Mechanism:
- Checks if the sender is a contract (not an EOA)
- Verifies the sender against an approved contract list
- Reverts transactions from unapproved contracts

Unique Design Elements:
- Only blocks interactions if a chain ID exists
- Allows approved contracts to interact
- Provides a flexible, reusable security pattern

The contract adds an extra layer of security by preventing potentially malicious smart contract interactions while maintaining flexibility for approved contracts.
 
 */

abstract contract Defensible {
    error UnauthorizedContract(address caller);

    /**
     * @notice Modifier to block unauthorized contract calls
     * @param bannedList Contract managing the banned contract registry
     */
    modifier defend(BannedContractList bannedList) {
        if (block.chainid > 0 && 
            msg.sender != tx.origin && 
            !bannedList.isApproved(msg.sender)) {
            revert UnauthorizedContract(msg.sender);
        }
        _;
    }
}