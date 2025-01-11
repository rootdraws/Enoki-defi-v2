// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategy {
    function invest(uint256 amount) external returns (uint256);
    function divest(uint256 amount) external returns (uint256);
    function totalValue() external view returns (uint256);
} 