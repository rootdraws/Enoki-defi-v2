// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// File Processed by Claude.AI Sonnet on 1/11/25.

// ENOKI TEAM VESTING CONTRACT

/**
 * 
 * Key Features:
 * - Linear vesting over time
 * - Cliff period before vesting starts
 * - Revocable by owner (optional)
 * - Supports any ERC20 token
 * - Gas optimized using unchecked blocks
 * - Updated to latest OpenZeppelin patterns
 */

contract TokenVesting is Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error CliffLongerThanDuration();
    error ZeroDuration();
    error FinalTimeBeforeCurrent();
    error NoTokensDue();
    error CannotRevoke();
    error AlreadyRevoked();

    event TokensReleased(address indexed token, uint256 amount);
    event TokenVestingRevoked(address indexed token);

    // Core vesting parameters - made immutable where possible
    address private immutable _beneficiary;
    uint256 private immutable _cliff;
    uint256 private immutable _start;
    uint256 private immutable _duration;
    bool private immutable _revocable;

    // Tracking for multiple tokens
    mapping(address token => uint256 amount) private _released;
    mapping(address token => bool status) private _revoked;

    constructor(
        address beneficiary_, // Address of beneficiary to receive the tokens
        uint256 start_, // Start time of the vesting period 
        uint256 cliffDuration_, // Duration of the cliff period
        uint256 duration_, // Duration of the vesting period
        bool revocable_ // Whether the vesting is revocable
    ) Ownable(msg.sender) {
        if (beneficiary_ == address(0)) revert ZeroAddress();
        if (cliffDuration_ > duration_) revert CliffLongerThanDuration();
        if (duration_ == 0) revert ZeroDuration();
        if (start_ + duration_ <= block.timestamp) revert FinalTimeBeforeCurrent();

        _beneficiary = beneficiary_;
        _revocable = revocable_;
        _duration = duration_;
        _cliff = start_ + cliffDuration_;
        _start = start_;
    }

    // Get the beneficiary address
    function beneficiary() external view returns (address) {
        return _beneficiary;
    }

    // Get the cliff timestamp
    function cliff() external view returns (uint256) {
        return _cliff;
    }

    // Get the start timestamp
    function start() external view returns (uint256) {
        return _start;
    }

    // Get the vesting duration
    function duration() external view returns (uint256) {
        return _duration;
    }

    // Check if the vesting is revocable
    function revocable() external view returns (bool) {
        return _revocable;
    }

    // Get the amount of tokens released for a given token
    function released(address token) external view returns (uint256) {
        return _released[token];
    }

    // Check if vesting has been revoked for a given token
    function revoked(address token) external view returns (bool) {
        return _revoked[token];
    }

    // Transfers vested ERC20 tokens to beneficiary
    function release(IERC20 token) external {
        uint256 unreleased = _releasableAmount(token);
        if (unreleased == 0) revert NoTokensDue();

        unchecked {
            _released[address(token)] += unreleased;
        }

        token.safeTransfer(_beneficiary, unreleased);

        emit TokensReleased(address(token), unreleased);
    }

    // Allows the owner to revoke the vesting
    function revoke(IERC20 token) external onlyOwner {
        if (!_revocable) revert CannotRevoke();
        if (_revoked[address(token)]) revert AlreadyRevoked();

        uint256 balance = token.balanceOf(address(this));
        uint256 unreleased = _releasableAmount(token);
        
        unchecked {
            uint256 refund = balance - unreleased;
            _revoked[address(token)] = true;
            token.safeTransfer(owner(), refund);
        }

        emit TokenVestingRevoked(address(token));
    }

    // Calculates the amount that has already vested but hasn't been released yet
    function _releasableAmount(IERC20 token) private view returns (uint256) {
        return _vestedAmount(token) - _released[address(token)];
    }

    // Calculates the amount that has already vested
    function _vestedAmount(IERC20 token) private view returns (uint256) {
        uint256 currentBalance = token.balanceOf(address(this));
        uint256 totalBalance;
        
        unchecked {
            totalBalance = currentBalance + _released[address(token)];
        }

        if (block.timestamp < _cliff) {
            return 0;
        }
        
        if (block.timestamp >= _start + _duration || _revoked[address(token)]) {
            return totalBalance;
        }

        unchecked {
            return (totalBalance * (block.timestamp - _start)) / _duration;
        }
    }
}