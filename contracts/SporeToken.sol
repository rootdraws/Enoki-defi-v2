// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title ModernSporeToken
 * @notice Advanced ERC20 token with controlled minting and transfer mechanisms
 * 
 * Key Features:
 * - Controlled minting and burning
 * - Flexible transfer restrictions
 * - Enhanced liquidity management
 * - Comprehensive access controls
 * 
 * Governance and Liquidity Mechanisms:
 * - DAO-controlled initial liquidity
 * - Selective transfer permissions
 * - Flexible minting rights
 */
contract ModernSporeToken is ERC20, ERC20Burnable, Ownable2Step {
    // Custom error types for gas-efficient error handling
    error TransfersNotEnabled();
    error InvalidMintAmount();
    error InvalidBurnAmount();  
    error UnauthorizedTransfer();
    error TransfersAlreadyEnabled();

    // Advanced permission tracking
    struct MinterConfig {
        bool canMint;
        uint256 maxMintAmount;
        uint256 mintedAmount;
    }

    // Core state variables
    address public immutable initialLiquidityManager;
    bool private _transfersEnabled;

    // Enhanced permission mappings
    mapping(address => MinterConfig) private _minterConfigs;
    mapping(address => bool) private _initialLiquidityTransferRights;

    // Supply tracking
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;
    uint256 private _totalMinted;
    
    // Events with comprehensive information 
    event TransfersEnabled(address indexed enabler, uint256 timestamp);
    event MinterAdded(address indexed minter, uint256 maxMintAmount);
    event MinterRemoved(address indexed minter);
    event InitialLiquidityTransferRightsGranted(address indexed account);

    /**
     * @notice Constructor initializes the token
     * @param _initialLiquidityManager Address managing initial liquidity
     */
    constructor(address _initialLiquidityManager) ERC20("SporeFinance", "SPORE") Ownable(msg.sender) {
        initialLiquidityManager = _initialLiquidityManager == address(0) ? msg.sender : _initialLiquidityManager;
        
        // Grant initial transfer and minting rights to deployer
        _initialLiquidityTransferRights[msg.sender] = true;
        _minterConfigs[msg.sender] = MinterConfig({
            canMint: true,
            maxMintAmount: type(uint256).max,
            mintedAmount: 0
        });
    }

    /**
     * @notice Override transfer with restricted transfer mechanism
     */
    function transfer(
        address recipient, 
        uint256 amount
    ) public virtual override returns (bool) {
        _checkTransferEligibility(msg.sender);
        return super.transfer(recipient, amount);
    }

    /**
     * @notice Override transferFrom with restricted transfer mechanism
     */
    function transferFrom(
        address sender, 
        address recipient, 
        uint256 amount
    ) public virtual override returns (bool) {
        _checkTransferEligibility(sender);
        return super.transferFrom(sender, recipient, amount);
    }

    /**
     * @notice Enhanced burning mechanism with total supply check
     * @param amount Amount of tokens to burn  
     */
    function burn(uint256 amount) public virtual override {
        if (amount == 0) revert InvalidBurnAmount();
        if (balanceOf(msg.sender) < amount) revert InvalidBurnAmount();

        // Check if the burn would result in negative supply
        uint256 newTotalSupply = totalSupply() - amount;
        if (newTotalSupply < _totalMinted) revert InvalidBurnAmount();
        
        super.burn(amount);
    }

    /**
     * @notice Mint tokens with advanced controls and total supply cap
     * @param to Recipient address
     * @param amount Amount to mint 
     */
    function mint(address to, uint256 amount) public {
        MinterConfig storage config = _minterConfigs[msg.sender];
        
        if (!config.canMint) revert UnauthorizedTransfer();
        if (amount == 0) revert InvalidMintAmount();

        // Check minting limits  
        if (config.mintedAmount + amount > config.maxMintAmount) {
            revert InvalidMintAmount();
        }

        // Check total supply cap 
        if (_totalMinted + amount > MAX_SUPPLY) {
            revert InvalidMintAmount();
        }

        // Update minting tracking
        config.mintedAmount += amount; 
        _totalMinted += amount;
        
        _mint(to, amount);
    }

    /**
     * @notice Grant initial liquidity transfer rights
     * @param account Address to grant rights  
     */
    function grantInitialLiquidityTransferRights(
        address account  
    ) external {
        if (_transfersEnabled) revert TransfersAlreadyEnabled();
        if (msg.sender != initialLiquidityManager) revert UnauthorizedTransfer();
        
        _initialLiquidityTransferRights[account] = true;
        
        emit InitialLiquidityTransferRightsGranted(account);
    }

    /**  
     * @notice Enable public transfers
     */
    function enableTransfers() external {
        if (_transfersEnabled) revert TransfersAlreadyEnabled();
        if (msg.sender != initialLiquidityManager) revert UnauthorizedTransfer();
        
        _transfersEnabled = true;
        
        emit TransfersEnabled(msg.sender, block.timestamp); 
    }

    /**
     * @notice Add a minter with configurable mint limits  
     * @param account Minter address
     * @param maxMintAmount Maximum allowed minting amount
     */
    function addMinter(
        address account, 
        uint256 maxMintAmount
    ) external onlyOwner {
        _minterConfigs[account] = MinterConfig({
            canMint: true,
            maxMintAmount: maxMintAmount,
            mintedAmount: 0  
        });
        
        emit MinterAdded(account, maxMintAmount);
    }

    /**
     * @notice Remove minter status
     * @param account Address to remove
     */
    function removeMinter(address account) external onlyOwner {
        delete _minterConfigs[account];
        
        emit MinterRemoved(account);
    }

    /**
     * @notice Internal transfer eligibility check  
     * @param sender Address initiating transfer
     */
    function _checkTransferEligibility(address sender) private view {
        if (_transfersEnabled) return;
        if (!_initialLiquidityTransferRights[sender]) {
            revert TransfersNotEnabled(); 
        }
    }
}