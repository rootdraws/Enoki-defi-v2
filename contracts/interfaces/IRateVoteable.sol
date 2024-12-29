// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRateVoteable {
    function changeRate(uint256 percentage) external;

    event RateChanged(uint256 percentage);
}