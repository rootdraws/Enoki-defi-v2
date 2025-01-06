// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// File Modernized by Claude.AI Sonnet on 1/4/25.

/**
 * @title OnlyEOAGuard
 * @dev Enhanced security contract to restrict function calls to Externally Owned Accounts (EOAs)
 * 
 * 
 
 This contract provides a basic security mechanism to restrict certain function calls to only Externally Owned Accounts (EOAs). It includes an abstract contract called OnlyEOAGuard which defines a modifier onlyEOA() that checks if the caller (msg.sender) is the same as the original transaction sender (tx.origin). If not, it means the call is coming from a contract, and it reverts with a custom error.

The SecureContract is an example implementation demonstrating how to use the OnlyEOAGuard. It has a state variable _value and two functions:
1. setValue(uint256 newValue) which is protected by the onlyEOA modifier, allowing only EOA callers to set the value.
2. getValue() which is a public view function that returns the current value.

However, it's important to note that this security mechanism is not foolproof and can be bypassed by sophisticated attack patterns. It should not be relied upon as the sole access control solution and should be used in conjunction with other security measures.
 
 * 
 * Security Considerations:
 * - Provides a basic protection against contract interactions
 * - Not a comprehensive security solution
 * - Recommended to use in conjunction with other security mechanisms
 * 
 * Limitations:
 * - Can be bypassed by sophisticated attack patterns
 * - Not recommended as the sole access control mechanism
 */

abstract contract OnlyEOAGuard {
    // Custom error for more gas-efficient error handling
    error OnlyExternallyOwnedAccountsAllowed();

    /**
     * @dev Modifier to restrict function access to Externally Owned Accounts
     * 
     * Key Mechanism:
     * - Compares msg.sender with tx.origin
     * - Ensures original transaction sender is an EOA
     * 
     * @notice This method is not foolproof and should not be solely relied upon
     */
    modifier onlyEOA() {
        _checkEOA();
        _;
    }

    /**
     * @dev Internal function to perform EOA check
     * Separated for potential override or future extension
     */
    function _checkEOA() internal view virtual {
        if (msg.sender != tx.origin) {
            revert OnlyExternallyOwnedAccountsAllowed();
        }
    }
}

/**
 * @title SecureContract
 * @dev Example implementation of OnlyEOAGuard
 */
contract SecureContract is OnlyEOAGuard {
    uint256 private _value;

    /**
     * @dev Example function protected by EOA check
     * @param newValue Value to be set
     */
    function setValue(uint256 newValue) external onlyEOA {
        _value = newValue;
    }

    /**
     * @dev Getter for the value
     * @return Current stored value
     */
    function getValue() external view returns (uint256) {
        return _value;
    }
}