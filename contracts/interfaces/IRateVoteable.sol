// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IRateVoteable {
    function changeRate(uint256 percentage) external;
}
