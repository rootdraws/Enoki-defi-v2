// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract ITokenPool {
    function token() external virtual view returns (IERC20);
    function balance() external virtual view returns (uint256);
    function transfer(address to, uint256 value) external virtual returns (bool);
    function rescueFunds(address tokenToRescue, address to, uint256 amount) external virtual returns (bool);

    event Transfer(address indexed to, uint256 value);
    event FundsRescued(address indexed tokenToRescue, address indexed to, uint256 amount);

}