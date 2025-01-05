// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IRateVoteable} from "./interfaces/IRateVoteable.sol";

// File Modernized by Claude.AI Sonnet on 1/4/25.

/**
 * @title CentralizedRateVote
 * @dev Enhanced admin contract for pool rate management
 * @custom:security-contact security@example.com
 */

contract CentralizedRateVote is Ownable, Pausable {
    /// @dev Maximum allowed percentage for rate multiplier
    uint256 public constant MAX_PERCENTAGE = 100;
    
    /// @dev Minimum allowed percentage for rate multiplier
    uint256 public constant MIN_PERCENTAGE = 1;

    /// @dev Reserved for future voting implementation
    uint256 private immutable _votingEnabledTimestamp;

    /// @dev Mapping to track rate history for each pool
    mapping(address => uint256[]) private _rateHistory;

    /// @dev Emitted when a pool's rate is modified
    event RateChanged(
        address indexed pool,
        uint256 oldRate,
        uint256 newRate,
        uint256 timestamp
    );

    /// @dev Emitted when rates are changed in batch
    event BatchRateChanged(
        address[] pools,
        uint256[] rates,
        uint256 timestamp
    );

    error InvalidRate(uint256 provided, uint256 max);
    error ZeroAddress();
    error InvalidPoolAddress();
    error ArrayLengthMismatch();
    error CallFailed();

    /**
     * @dev Constructor sets initial configuration
     */
    constructor() Ownable(msg.sender) {
        _votingEnabledTimestamp = block.timestamp + 365 days; // Example timelock
        _pause(); // Start paused for safety
    }

    /**
     * @dev Modify rate multiplier for a single pool
     * @param pool Target pool address
     * @param rateMultiplier New rate value to set
     */
    function changeRate(
        IRateVoteable pool,
        uint256 rateMultiplier
    ) external onlyOwner whenNotPaused {
        if (address(pool) == address(0)) revert ZeroAddress();
        if (!_isContract(address(pool))) revert InvalidPoolAddress();
        if (rateMultiplier > MAX_PERCENTAGE || rateMultiplier < MIN_PERCENTAGE) {
            revert InvalidRate(rateMultiplier, MAX_PERCENTAGE);
        }

        uint256 oldRate = pool.getCurrentRate();
        
        // Use try-catch for external call safety
        try pool.changeRate(rateMultiplier) {
            _rateHistory[address(pool)].push(rateMultiplier);
            
            emit RateChanged(
                address(pool),
                oldRate,
                rateMultiplier,
                block.timestamp
            );
        } catch {
            revert CallFailed();
        }
    }

    /**
     * @dev Batch modify rates for multiple pools
     * @param pools Array of pool addresses
     * @param rates Array of new rate values
     */
    function batchChangeRates(
        IRateVoteable[] calldata pools,
        uint256[] calldata rates
    ) external onlyOwner whenNotPaused {
        if (pools.length != rates.length) revert ArrayLengthMismatch();
        
        uint256 length = pools.length;
        for (uint256 i = 0; i < length;) {
            if (address(pools[i]) == address(0)) revert ZeroAddress();
            if (!_isContract(address(pools[i]))) revert InvalidPoolAddress();
            if (rates[i] > MAX_PERCENTAGE || rates[i] < MIN_PERCENTAGE) {
                revert InvalidRate(rates[i], MAX_PERCENTAGE);
            }
            
            try pools[i].changeRate(rates[i]) {
                _rateHistory[address(pools[i])].push(rates[i]);
                unchecked { ++i; }
            } catch {
                revert CallFailed();
            }
        }
        
        emit BatchRateChanged(
            _convertToAddressArray(pools),
            rates,
            block.timestamp
        );
    }

    /**
     * @dev Get rate history for a specific pool
     * @param pool Pool address to query
     * @return uint256[] Array of historical rates
     */
    function getRateHistory(
        address pool
    ) external view returns (uint256[] memory) {
        return _rateHistory[pool];
    }

    /**
     * @dev Check if address contains contract code
     * @param account Address to check
     * @return bool True if address contains code
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Convert IRateVoteable array to address array
     * @param pools Array of IRateVoteable interfaces
     * @return address[] Array of addresses
     */
    function _convertToAddressArray(
        IRateVoteable[] calldata pools
    ) internal pure returns (address[] memory) {
        address[] memory addresses = new address[](pools.length);
        for (uint256 i = 0; i < pools.length;) {
            addresses[i] = address(pools[i]);
            unchecked { ++i; }
        }
        return addresses;
    }

    /**
     * @dev Pause contract functionality
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause contract functionality
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}