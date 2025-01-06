// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BannedContractList} from "./BannedContractList.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title Defensible
 * @notice Lightweight security contract to protect against unauthorized contract interactions
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