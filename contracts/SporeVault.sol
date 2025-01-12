// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// SPORE VAULT CONTRACT | FACTORY INSTANCE
// This is a vault contract for the Spore ecosystem. It is used to deposit and withdraw tokens.

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// Each Vault is assigned a Strategy Contract.
interface IStrategy {
    function invest(uint256 amount) external returns (uint256);
    function divest(uint256 amount) external returns (uint256);
    function totalValue() external view returns (uint256);
}

contract SporeVault is ERC4626Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20 for IERC20;

    error InvalidStrategy();
    error NotFactory();
    error ZeroAssets();
    error ZeroAddress();

    IERC20 public depositToken;
    ISporeToken public sporeToken;
    IStrategy public strategy;
    address public factory;
    
    event StrategySet(address indexed strategy);

    constructor(IERC20 _depositToken) {
        depositToken = _depositToken;
        _disableInitializers();
    }

    function initialize(
        ISporeToken _sporeToken,
        address _daoRewardAddress,
        uint256 _rewardRate,
        string memory _name,
        string memory _symbol,
        IERC20 _depositToken
    ) external initializer {
        depositToken = _depositToken;
        sporeToken = _sporeToken;
        factory = msg.sender;
        
        __ERC4626_init(IERC20(address(depositToken)));
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
    }

    function setStrategy(address _strategy) external {
        if (msg.sender != factory) revert NotFactory();
        if (_strategy == address(0)) revert InvalidStrategy();
        
        if (address(strategy) != address(0)) {
            uint256 strategyBalance = strategy.totalValue();
            if (strategyBalance > 0) {
                strategy.divest(strategyBalance);
            }
        }

        strategy = IStrategy(_strategy);
        emit StrategySet(_strategy);
    }

    function totalAssets() public view override returns (uint256) {
        return depositToken.balanceOf(address(this)) + 
               (address(strategy) != address(0) ? strategy.totalValue() : 0);
    }

    function deposit(uint256 assets, address receiver) public override nonReentrant whenNotPaused returns (uint256) {
        if (assets == 0) revert ZeroAssets();
        if (receiver == address(0)) revert ZeroAddress();
        
        SafeERC20.safeTransferFrom(depositToken, msg.sender, address(this), assets);
        
        uint256 shares = super.previewDeposit(assets);
        _mint(receiver, shares);
        
        if (address(strategy) != address(0)) {
            strategy.invest(assets);
        }
        
        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    function withdraw(uint256 assets, address receiver, address owner) public override nonReentrant whenNotPaused returns (uint256) {
        if (assets == 0) revert ZeroAssets();
        if (receiver == address(0)) revert ZeroAddress();
        if (owner == address(0)) revert ZeroAddress();

        uint256 shares = super.previewWithdraw(assets);
        
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }
        
        if (address(strategy) != address(0)) {
            uint256 vaultBalance = depositToken.balanceOf(address(this));
            if (vaultBalance < assets) {
                uint256 neededAmount = assets - vaultBalance;
                strategy.divest(neededAmount);
            }
        }

        _burn(owner, shares);
        depositToken.safeTransfer(receiver, assets);
        
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }
} 