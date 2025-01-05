// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

// File Modernized by Claude.AI Sonnet on 1/4/25.

/**
 * @title BannedContractList
 * @dev Enhanced contract for maintaining a blacklist of banned contracts
 * @custom:security-contact security@example.com
 */

contract BannedContractList is Ownable, Pausable {
    /// @dev Emitted when a contract's banned status changes
    event ContractStatusChanged(address indexed contractAddress, bool isBanned);
    
    /// @dev Emitted when multiple contracts' statuses are updated
    event BatchStatusChanged(address[] contractAddresses, bool isBanned);

    /// @dev Maps address to banned status (true = banned, false = approved)
    mapping(address => bool) private _banned;

    error ZeroAddress();
    error NothingToUpdate();
    error InvalidArrayLength();

    /**
     * @dev Constructor to set initial owner and security settings
     */
    constructor() Ownable(msg.sender) {
        _pause(); // Start paused for safety
    }

    /**
     * @dev Check if contract is approved (not banned)
     * @param toCheck Address to check approval status
     * @return bool True if contract is approved
     */
    function isApproved(address toCheck) external view returns (bool) {
        return !_banned[toCheck];
    }

    /**
     * @dev Check if contract is banned
     * @param toCheck Address to check ban status
     * @return bool True if contract is banned
     */
    function isBanned(address toCheck) external view returns (bool) {
        return _banned[toCheck];
    }

    /**
     * @dev Remove contract from ban list
     * @param toApprove Address to approve
     */
    function approveContract(address toApprove) external onlyOwner whenNotPaused {
        if (toApprove == address(0)) revert ZeroAddress();
        if (!_banned[toApprove]) revert NothingToUpdate();

        _banned[toApprove] = false;
        emit ContractStatusChanged(toApprove, false);
    }

    /**
     * @dev Add contract to ban list
     * @param toBan Address to ban
     */
    function banContract(address toBan) external onlyOwner whenNotPaused {
        if (toBan == address(0)) revert ZeroAddress();
        if (_banned[toBan]) revert NothingToUpdate();

        _banned[toBan] = true;
        emit ContractStatusChanged(toBan, true);
    }

    /**
     * @dev Batch update contract statuses
     * @param contracts Array of addresses to update
     * @param banned New banned status to apply
     */
    function batchUpdateStatus(
        address[] calldata contracts,
        bool banned
    ) external onlyOwner whenNotPaused {
        uint256 length = contracts.length;
        if (length == 0) revert InvalidArrayLength();

        for (uint256 i = 0; i < length;) {
            address contractAddress = contracts[i];
            if (contractAddress == address(0)) revert ZeroAddress();
            
            _banned[contractAddress] = banned;
            unchecked { ++i; }
        }

        emit BatchStatusChanged(contracts, banned);
    }

    /**
     * @dev Pause the contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}