// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISporeToken {
    function mint(address to, uint256 amount) external returns (bool);
}