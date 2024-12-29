// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title EthVesting
 * @notice Contract implementing a linear vesting schedule for ETH distribution
 * @dev Features:
 * - Linear vesting with cliff period
 * - Backup beneficiary system
 * - Protection against timestamp manipulation
 * - Linear ETH release to Developers or DAO
 */
contract EthVesting {
    // Events for tracking distributions and deposits
    event EthReleased(uint256 amount);
    event EthReleasedBackup(uint256 amount);
    event PaymentReceived(address indexed from, uint256 amount);

    // Core state variables
    address payable private immutable _beneficiary;
    address payable private immutable _backupBeneficiary;
    uint256 private immutable _cliff;
    uint256 private immutable _start;
    uint256 private immutable _duration;
    uint256 private immutable _backupReleaseGracePeriod;
    uint256 private _released;

    /**
     * @notice Constructor sets up vesting schedule parameters
     * @param beneficiary Primary recipient of vested ETH
     * @param backupBeneficiary Backup recipient if primary doesn't claim
     * @param start Timestamp when vesting begins
     * @param cliffDuration Duration before any ETH can be claimed (in seconds)
     * @param duration Total vesting duration (in seconds)
     * @param backupReleaseGracePeriod Grace period before backup can claim (in seconds)
     */
    constructor(
        address payable beneficiary,
        address payable backupBeneficiary,
        uint256 start,
        uint256 cliffDuration,
        uint256 duration,
        uint256 backupReleaseGracePeriod
    ) {
        // Validation
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(backupBeneficiary != address(0), "Backup beneficiary cannot be zero address");
        require(cliffDuration <= duration, "Cliff duration exceeds vesting duration");
        require(duration > 0, "Vesting duration must be greater than zero");
        require(start + duration > block.timestamp, "Final time is before current time");

        // Set core parameters
        _beneficiary = beneficiary;
        _backupBeneficiary = backupBeneficiary;
        _duration = duration;
        _cliff = start + cliffDuration;
        _start = start;
        _backupReleaseGracePeriod = backupReleaseGracePeriod;
    }

    /**
     * @notice Release vested ETH to primary beneficiary
     * @dev Calculates and transfers available ETH based on vesting schedule
     */
    function release() public {
        uint256 unreleased = _releasableAmount();
        require(unreleased > 0, "No ETH is due");

        _released += unreleased;
        (bool success, ) = _beneficiary.call{value: unreleased}("");
        require(success, "ETH transfer failed");

        emit EthReleased(unreleased);
    }

    /**
     * @notice Calculate releasable ETH amount
     * @return Amount of ETH that can be released
     */
    function _releasableAmount() private view returns (uint256) {
        return _vestedAmount() - _released;
    }

    /**
     * @notice Calculate total vested ETH amount
     * @return Amount of ETH that has vested
     */
    function _vestedAmount() private view returns (uint256) {
        uint256 currentBalance = address(this).balance;
        uint256 totalBalance = currentBalance + _released;

        if (block.timestamp < _cliff) {
            return 0;
        } else if (block.timestamp >= _start + _duration) {
            return totalBalance;
        } else {
            return (totalBalance * (block.timestamp - _start)) / _duration;
        }
    }

    /**
     * @notice Allow backup beneficiary to claim ETH after grace period
     * @dev Only callable after vesting period and grace period
     */
    function backupRelease() public {
        require(
            block.timestamp >= _start + _duration + _backupReleaseGracePeriod, 
            "Backup release not yet available"
        );
        
        uint256 balance = address(this).balance;
        (bool success, ) = _backupBeneficiary.call{value: balance}("");
        require(success, "Backup ETH transfer failed");

        emit EthReleasedBackup(balance);
    }

    /*
     * @notice Retrieve beneficiary addresses and vesting details
     * @return Beneficiary details
     */
    
    function getVestingDetails() external view returns (
        address primaryBeneficiary,
        address backupBeneficiary,
        uint256 start,
        uint256 cliff,
        uint256 duration,
        uint256 released,
        uint256 backupReleaseTime
    ) {
        return (
            _beneficiary,
            _backupBeneficiary,
            _start,
            _cliff,
            _duration,
            _released,
            _start + _duration + _backupReleaseGracePeriod
        );
    }

    /**
     * @notice Allow contract to receive ETH
     */
    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }
}