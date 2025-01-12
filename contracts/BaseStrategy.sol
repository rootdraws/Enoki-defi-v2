// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IStrategy.sol";

abstract contract BaseStrategy is IStrategy, Ownable {
    error UnauthorizedCaller();
    error InvalidAmount();
    error TransferFailed();

    IERC20 public immutable asset;
    address public immutable vault;

    event Invested(uint256 amount);
    event Divested(uint256 amount);

    constructor(IERC20 _asset, address _vault) {
        asset = _asset;
        vault = _vault;
    }

    modifier onlyVault() {
        if (msg.sender != vault) revert UnauthorizedCaller();
        _;
    }

    function invest(uint256 amount) external virtual override onlyVault returns (uint256) {
        if (amount == 0) revert InvalidAmount();
        return _invest(amount);
    }

    function divest(uint256 amount) external virtual override onlyVault returns (uint256) {
        if (amount == 0) revert InvalidAmount();
        return _divest(amount);
    }

    function totalValue() external view virtual override returns (uint256);

    function _invest(uint256 amount) internal virtual returns (uint256);
    function _divest(uint256 amount) internal virtual returns (uint256);

    function sweep(IERC20 token) external onlyOwner {
        if (address(token) == address(asset)) revert UnauthorizedCaller();
        token.transfer(owner(), token.balanceOf(address(this)));
    }
} 