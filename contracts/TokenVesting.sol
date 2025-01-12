// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// File Processed by Claude.AI Sonnet on 1/11/25.

// ENOKI TEAM VESTING CONTRACT | UTILITY CONTRACT
// Linear vesting two years after the contract is deployed.
// Deposit tokens into the contract to vest them over time.

contract TokenVesting is Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error NoTokensDue();

    event TokensReleased(address indexed token, uint256 amount);

    // Core vesting parameters - made immutable where possible
    address private immutable _beneficiary;
    uint256 private immutable _start;
    uint256 private immutable _duration;

    // Tracking for multiple tokens
    mapping(address token => uint256 amount) private _released;

    constructor(
        address beneficiary_ // Address of beneficiary to receive the tokens
    ) Ownable(msg.sender) {
        if (beneficiary_ == address(0)) revert ZeroAddress();

        _beneficiary = beneficiary_;
        _start = block.timestamp;
        _duration = 730 days; // 2 years in days
    }

    // Get the beneficiary address
    function beneficiary() external view returns (address) {
        return _beneficiary;
    }

    // Get the start timestamp
    function start() external view returns (uint256) {
        return _start;
    }

    // Get the vesting duration
    function duration() external view returns (uint256) {
        return _duration;
    }

    // Get the amount of tokens released for a given token
    function released(address token) external view returns (uint256) {
        return _released[token];
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
        
        if (block.timestamp >= _start + _duration) {
            return totalBalance;
        }

        unchecked {
            return (totalBalance * (block.timestamp - _start)) / _duration;
        }
    }
}