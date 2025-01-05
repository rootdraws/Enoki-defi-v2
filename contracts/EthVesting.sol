// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// File Modernized by Claude.AI Sonnet on 1/4/25.

/**
 * @title EthVesting
 * @notice Advanced linear vesting schedule for ETH distribution
 * @dev Implements secure vesting with backup beneficiary system
 * @custom:security-contact security@example.com
 */

contract EthVesting is ReentrancyGuard, Pausable {
    /// @notice Events for tracking vesting operations
    event EthReleased(address indexed beneficiary, uint256 amount, uint256 timestamp);
    event EthReleasedBackup(address indexed backupBeneficiary, uint256 amount, uint256 timestamp);
    event PaymentReceived(address indexed from, uint256 amount, uint256 timestamp);

    /// @dev Custom errors for better gas efficiency
    error ZeroAddress();
    error InvalidDuration();
    error InvalidCliffDuration();
    error InvalidSchedule();
    error NoEthDue();
    error TransferFailed();
    error BackupReleaseNotAvailable();
    error InvalidAmount();

    /// @notice Core state variables
    address payable private immutable _beneficiary;
    address payable private immutable _backupBeneficiary;
    uint256 private immutable _cliff;
    uint256 private immutable _start;
    uint256 private immutable _duration;
    uint256 private immutable _backupReleaseGracePeriod;
    
    /// @notice Vesting accounting
    uint256 private _released;
    uint256 private _lastReleaseTime;
    uint256 private _totalDeposited;

    /// @notice Minimum values for safety
    uint256 private constant MIN_DURATION = 1 days;
    uint256 private constant MIN_GRACE_PERIOD = 7 days;
    uint256 private constant MAX_DURATION = 3650 days;

    /**
     * @notice Constructor sets up vesting schedule parameters
     * @param beneficiary_ Primary recipient of vested ETH
     * @param backupBeneficiary_ Backup recipient if primary doesn't claim
     * @param start_ Timestamp when vesting begins
     * @param cliffDuration_ Duration before any ETH can be claimed (in seconds)
     * @param duration_ Total vesting duration (in seconds)
     * @param backupReleaseGracePeriod_ Grace period before backup can claim (in seconds)
     */
    constructor(
        address payable beneficiary_,
        address payable backupBeneficiary_,
        uint256 start_,
        uint256 cliffDuration_,
        uint256 duration_,
        uint256 backupReleaseGracePeriod_
    ) {
        if (beneficiary_ == address(0)) revert ZeroAddress();
        if (backupBeneficiary_ == address(0)) revert ZeroAddress();
        if (duration_ < MIN_DURATION || duration_ > MAX_DURATION) revert InvalidDuration();
        if (cliffDuration_ > duration_) revert InvalidCliffDuration();
        if (start_ + duration_ <= block.timestamp) revert InvalidSchedule();
        if (backupReleaseGracePeriod_ < MIN_GRACE_PERIOD) revert InvalidDuration();

        _beneficiary = beneficiary_;
        _backupBeneficiary = backupBeneficiary_;
        _duration = duration_;
        _cliff = start_ + cliffDuration_;
        _start = start_;
        _backupReleaseGracePeriod = backupReleaseGracePeriod_;
        _lastReleaseTime = start_;
    }

    /**
     * @notice Release vested ETH to primary beneficiary
     * @dev Calculates and transfers available ETH based on vesting schedule
     */
    function release() external nonReentrant whenNotPaused {
        uint256 unreleased = _releasableAmount();
        if (unreleased == 0) revert NoEthDue();

        _released += unreleased;
        _lastReleaseTime = block.timestamp;

        (bool success, ) = _beneficiary.call{value: unreleased}("");
        if (!success) revert TransferFailed();

        emit EthReleased(_beneficiary, unreleased, block.timestamp);
    }

    /**
     * @notice Allow backup beneficiary to claim ETH after grace period
     * @dev Only callable after vesting period and grace period
     */
    function backupRelease() external nonReentrant whenNotPaused {
        uint256 backupReleaseTime = _start + _duration + _backupReleaseGracePeriod;
        if (block.timestamp < backupReleaseTime) revert BackupReleaseNotAvailable();
        
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoEthDue();

        (bool success, ) = _backupBeneficiary.call{value: balance}("");
        if (!success) revert TransferFailed();

        emit EthReleasedBackup(_backupBeneficiary, balance, block.timestamp);
    }

    /**
     * @notice Calculate total vested ETH amount
     * @return Amount of ETH that has vested
     */
    function vestedAmount() public view returns (uint256) {
        if (block.timestamp < _cliff) {
            return 0;
        }

        uint256 currentBalance = address(this).balance;
        uint256 totalBalance = currentBalance + _released;

        if (block.timestamp >= _start + _duration) {
            return totalBalance;
        }

        return (totalBalance * (block.timestamp - _start)) / _duration;
    }

    /**
     * @notice Calculate releasable ETH amount
     * @return Amount of ETH that can be released
     */
    function releasableAmount() external view returns (uint256) {
        return _releasableAmount();
    }

    /**
     * @notice Internal function to calculate releasable amount
     * @return Amount of ETH available for release
     */
    function _releasableAmount() private view returns (uint256) {
        return vestedAmount() - _released;
    }

    /**
     * @notice Get detailed vesting schedule information
     * @return primaryBeneficiary Address of the primary beneficiary
     * @return backupBeneficiary Address of the backup beneficiary
     * @return start Start timestamp of vesting period
     * @return cliff Cliff timestamp before which no vesting occurs
     * @return duration Total duration of the vesting period
     * @return released Amount of ETH already released
     * @return backupReleaseTime Timestamp when backup beneficiary can claim
     * @return lastReleaseTime Timestamp of last release
     * @return totalDeposited Total amount of ETH deposited
     * @return currentBalance Current ETH balance of contract
     */
    
    function getVestingDetails() external view returns (
        address primaryBeneficiary,
        address backupBeneficiary,
        uint256 start,
        uint256 cliff,
        uint256 duration,
        uint256 released,
        uint256 backupReleaseTime,
        uint256 lastReleaseTime,
        uint256 totalDeposited,
        uint256 currentBalance
    ) {
        return (
            _beneficiary,
            _backupBeneficiary,
            _start,
            _cliff,
            _duration,
            _released,
            _start + _duration + _backupReleaseGracePeriod,
            _lastReleaseTime,
            _totalDeposited,
            address(this).balance
        );
    }

    /**
     * @notice Pause vesting operations
     * @dev Only owner can pause
     */
    function pause() external {
        _pause();
    }

    /**
     * @notice Unpause vesting operations
     * @dev Only owner can unpause
     */
    function unpause() external {
        _unpause();
    }

    /**
     * @notice Allow contract to receive ETH
     */
    receive() external payable {
        if (msg.value == 0) revert InvalidAmount();
        _totalDeposited += msg.value;
        emit PaymentReceived(msg.sender, msg.value, block.timestamp);
    }
}