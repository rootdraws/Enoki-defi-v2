// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BaseStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendingStrategy is BaseStrategy {
    ILendingPool public immutable lendingPool;

    constructor(
        IERC20 _asset,
        address _vault,
        ILendingPool _lendingPool
    ) BaseStrategy(_asset, _vault) {
        lendingPool = _lendingPool;
    }

    function _invest(uint256 amount) internal override returns (uint256) {
        asset.approve(address(lendingPool), amount);
        lendingPool.deposit(address(asset), amount, address(this), 0);
        emit Invested(amount);
        return amount;
    }

    function _divest(uint256 amount) internal override returns (uint256) {
        lendingPool.withdraw(address(asset), amount, address(this));
        emit Divested(amount);
        return amount;
    }

    function totalValue() external view override returns (uint256) {
        return lendingPool.balanceOf(address(this));
    }
} 