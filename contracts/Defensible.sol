// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BannedContractList} from "./BannedContractList.sol";

// File Modernized by Claude.AI Sonnet on 1/4/25.

/**
 * @title Defensible
 * @notice Security contract that protects against unauthorized contract interactions
 * @dev Abstract contract providing defensive modifiers against unwanted contract calls
 * @custom:security-contact security@example.com
 */

abstract contract Defensible {
    /// @dev Emitted when an unauthorized contract attempts to call a defended function
    event UnauthorizedContractCall(
        address indexed caller,
        address indexed origin,
        bytes4 indexed selector
    );

    /// @dev Custom error for unauthorized contract calls
    error UnauthorizedContract(address caller);
    
    /// @dev Custom error for invalid banned contract list
    error InvalidBannedList();

    /**
     * @notice Modifier to protect against unauthorized contract calls
     * @dev Allows EOA calls or approved contract calls
     * @param bannedContractList Contract managing the banned contract registry
     */
    modifier defend(BannedContractList bannedContractList) {
        _validateBannedList(address(bannedContractList));
        _checkDefensibleConditions(bannedContractList);
        _;
    }

    /**
     * @notice Enhanced modifier that logs unauthorized attempts
     * @dev Same as defend but with event emission for monitoring
     * @param bannedContractList Contract managing the banned contract registry
     */
    modifier defendWithLogging(BannedContractList bannedContractList) {
        _validateBannedList(address(bannedContractList));
        
        if (_shouldBlock(bannedContractList)) {
            emit UnauthorizedContractCall(
                msg.sender,
                tx.origin,
                msg.sig
            );
            revert UnauthorizedContract(msg.sender);
        }
        _;
    }

    /**
     * @notice Internal function to check if caller is authorized
     * @dev Validates against banned contract list
     * @param bannedContractList The contract registry to check against
     */
    function _checkDefensibleConditions(
        BannedContractList bannedContractList
    ) internal view {
        if (_shouldBlock(bannedContractList)) {
            revert UnauthorizedContract(msg.sender);
        }
    }

    /**
     * @dev Determines if the call should be blocked
     * @param bannedContractList Contract registry to check
     * @return bool True if call should be blocked
     */
    function _shouldBlock(
        BannedContractList bannedContractList
    ) internal view returns (bool) {
        return msg.sender != tx.origin && 
               !bannedContractList.isApproved(msg.sender);
    }

    /**
     * @dev Validates banned contract list address
     * @param bannedList Address to validate
     */
    function _validateBannedList(address bannedList) private view {
        if (bannedList == address(0)) revert InvalidBannedList();
        
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(bannedList)
        }
        if (codeSize == 0) revert InvalidBannedList();
    }

    /**
     * @dev Checks if the current call is from a contract
     * @return bool True if caller is a contract
     */
    function _isContractCall() internal view returns (bool) {
        return msg.sender != tx.origin;
    }
}