// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

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

contract BannedContractList is Ownable {
    // Maps address to banned status (true = banned, false = approved)
    mapping(address => bool) private _banned;

    /**
     * @dev Check if contract is approved (not banned)
     */
    function isApproved(address toCheck) external view returns (bool) {
        return !_banned[toCheck];
    }

    /**
     * @dev Check if contract is banned
     */
    function isBanned(address toCheck) external view returns (bool) {
        return _banned[toCheck];
    }

    /**
     * @dev Remove contract from ban list (owner only)
     */
    function approveContract(address toApprove) external onlyOwner {
        _banned[toApprove] = false;
    }

    /**
     * @dev Add contract to ban list (owner only) 
     */
    function banContract(address toBan) external onlyOwner {
        _banned[toBan] = true;
    }

    // Constructor to set initial owner
    constructor() Ownable(msg.sender) {}
}