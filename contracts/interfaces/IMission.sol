// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMission {
    function sendSpores(address payable recipient, uint256 amount) external;
    function approvePool(address pool) external;
    function revokePool(address pool) external;

    event PoolApproved(address indexed pool);
    event PoolRevoked(address indexed pool);
}