// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// File Modernized by Claude.AI Sonnet on 1/4/25.

/**
 * @title ModernPaymentSplitter
 * @dev Advanced contract for splitting ETH payments between multiple recipients
 * 
 
 This is a modern, gas-optimized ETH payment splitting contract. It allows distributing incoming ETH payments among a predefined set of payees based on their assigned shares. Key features include secure payment handling, flexible share allocation, and comprehensive error handling using custom errors. The contract provides functions to view total shares, released amounts, and individual payee information. It is designed for use cases like team compensation, project funding distribution, and revenue sharing.
 
 * 
 * 
 * Features:
 * - Gas-efficient implementation
 * - Secure payment distribution
 * - Flexible share allocation
 * - Comprehensive error handling
 * 
 * Use Cases:
 * - Team compensation
 * - Project funding distribution
 * - Revenue sharing
 */

contract ModernPaymentSplitter {
    // Custom errors for more gas-efficient error handling
    error InvalidPayee(address account);
    error InvalidShares(uint256 shares);
    error DuplicatePayee(address account);
    error NoPaymentDue(address account);
    error TransferFailed(address recipient, uint256 amount);

    // Events using indexed parameters for efficient filtering
    event PayeeAdded(address indexed account, uint256 shares);
    event PaymentReleased(address indexed to, uint256 amount);
    event PaymentReceived(address indexed from, uint256 amount);

    // State variables using storage efficiently
    uint256 private immutable _totalShares;
    uint256 private _totalReleased;

    // Packed storage for more gas-efficient mappings
    mapping(address payee => PayeeInfo) private _payeeInfo;
    address[] private _payees;

    // Compact struct to pack storage and reduce gas costs
    struct PayeeInfo {
        uint256 shares;
        uint256 released;
    }

    /**
     * @dev Constructor to set up initial payees and their shares
     * @param payees_ Array of recipient addresses
     * @param shares_ Array of share amounts corresponding to payees
     */
    constructor(address[] memory payees_, uint256[] memory shares_) {
        // Validate input arrays
        if (payees_.length == 0) revert InvalidPayee(address(0));
        if (payees_.length != shares_.length) revert InvalidShares(0);

        // Track total shares and add payees
        uint256 totalSharesAccumulator;
        for (uint256 i; i < payees_.length; ++i) {
            _addPayee(payees_[i], shares_[i]);
            totalSharesAccumulator += shares_[i];
        }
        _totalShares = totalSharesAccumulator;
    }

    /**
     * @dev Receive function to handle direct ETH transfers
     */
    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    /**
     * @dev Release payment for a specific account
     * @param account Address to release payment to
     */
    function release(address payable account) external {
        // Validate payee
        PayeeInfo memory payeeInfo = _payeeInfo[account];
        if (payeeInfo.shares == 0) revert InvalidPayee(account);

        // Calculate pending payment
        uint256 totalReceived = address(this).balance + _totalReleased;
        uint256 payment = (totalReceived * payeeInfo.shares) / _totalShares - payeeInfo.released;
        
        if (payment == 0) revert NoPaymentDue(account);

        // Update accounting
        _payeeInfo[account].released += payment;
        _totalReleased += payment;

        // Perform transfer with robust error handling
        (bool success, ) = account.call{value: payment}("");
        if (!success) revert TransferFailed(account, payment);

        emit PaymentReleased(account, payment);
    }

    /**
     * @dev Add a new payee to the payment splitter
     * @param account Payee address to add
     * @param shares_ Number of shares for the payee
     */
    function _addPayee(address account, uint256 shares_) private {
        // Comprehensive input validation
        if (account == address(0)) revert InvalidPayee(account);
        if (shares_ == 0) revert InvalidShares(shares_);
        if (_payeeInfo[account].shares != 0) revert DuplicatePayee(account);

        // Update payee information
        _payeeInfo[account] = PayeeInfo({
            shares: shares_,
            released: 0
        });
        _payees.push(account);

        emit PayeeAdded(account, shares_);
    }

    /**
     * @dev Get total number of shares
     * @return Total shares across all payees
     */
    function totalShares() external view returns (uint256) {
        return _totalShares;
    }

    /**
     * @dev Get total amount of ETH released
     * @return Total ETH released so far
     */
    function totalReleased() external view returns (uint256) {
        return _totalReleased;
    }

    /**
     * @dev Get shares for a specific account
     * @param account Address to check shares for
     * @return Number of shares for the account
     */
    function sharesOf(address account) external view returns (uint256) {
        return _payeeInfo[account].shares;
    }

    /**
     * @dev Get amount released for a specific account
     * @param account Address to check released amount
     * @return Amount of ETH released to the account
     */
    function releasedOf(address account) external view returns (uint256) {
        return _payeeInfo[account].released;
    }

    /**
     * @dev Get payee address by index
     * @param index Index of the payee
     * @return Address of the payee at the given index
     */
    function payeeAt(uint256 index) external view returns (address) {
        return _payees[index];
    }

    /**
     * @dev Get total number of payees
     * @return Number of payees in the contract
     */
    function payeeCount() external view returns (uint256) {
        return _payees.length;
    }
}