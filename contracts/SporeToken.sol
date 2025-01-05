// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title ModernSporeToken
 * @notice Advanced ERC20 token with controlled minting and transfer mechanisms
 * @dev Implements EIP-2612 permit for gasless approvals
 * 
 * Key Features:
 * - Controlled minting and burning with reentrancy protection
 * - Flexible transfer restrictions
 * - Enhanced liquidity management
 * - Comprehensive access controls
 * - EIP-2612 permit support for gasless transactions
 * - Explicit decimal specification
 */

contract ModernSporeToken is 
    ERC20, 
    ERC20Permit, 
    ERC20Burnable, 
    Ownable2Step,
    ReentrancyGuard 
{
    // Custom errors with descriptive parameters
    error TransfersNotEnabled(address sender);
    error InvalidMintAmount(uint256 requested, uint256 remaining);
    error InvalidBurnAmount(uint256 amount, uint256 balance);
    error UnauthorizedTransfer(address sender);
    error TransfersAlreadyEnabled();
    error ExceedsMaxSupply(uint256 requested, uint256 remaining);
    error ZeroAddress();

    // Advanced permission tracking
    struct MinterConfig {
        bool canMint;
        uint256 maxMintAmount;
        uint256 mintedAmount;
    }

    // Core state variables
    address public immutable initialLiquidityManager;
    bool private _transfersEnabled;

    // Enhanced permission mappings with explicit naming
    mapping(address minter => MinterConfig config) private _minterConfigs;
    mapping(address account => bool hasRights) private _initialLiquidityTransferRights;

    // Supply tracking with explicit decimal handling
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 private _totalMinted;
    uint8 private constant DECIMALS = 18;
    
    // Events with comprehensive information
    event TransfersEnabled(address indexed enabler, uint256 timestamp);
    event MinterAdded(address indexed minter, uint256 maxMintAmount);
    event MinterRemoved(address indexed minter);
    event InitialLiquidityTransferRightsGranted(address indexed account);
    event TokensBurned(address indexed burner, uint256 amount);
    event TokensMinted(address indexed minter, address indexed to, uint256 amount);

    /**
     * @notice Constructor initializes the token with EIP-2612 support
     * @param _initialLiquidityManager Address managing initial liquidity
     */
    constructor(
        address _initialLiquidityManager
    ) ERC20("SporeFinance", "SPORE") ERC20Permit("SporeFinance") Ownable(msg.sender) {
        if (_initialLiquidityManager == address(0)) revert ZeroAddress();
        
        initialLiquidityManager = _initialLiquidityManager;
        
        _initialLiquidityTransferRights[msg.sender] = true;
        _minterConfigs[msg.sender] = MinterConfig({
            canMint: true,
            maxMintAmount: type(uint256).max,
            mintedAmount: 0
        });
    }

    /**
     * @notice Override decimals to explicitly set precision
     */
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /**
     * @notice Override transfer with restricted transfer mechanism
     * @dev Includes nonReentrant modifier for additional security
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override nonReentrant returns (bool) {
        _checkTransferEligibility(msg.sender);
        return super.transfer(recipient, amount);
    }

    /**
     * @notice Override transferFrom with restricted transfer mechanism
     * @dev Includes nonReentrant modifier for additional security
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override nonReentrant returns (bool) {
        _checkTransferEligibility(sender);
        return super.transferFrom(sender, recipient, amount);
    }

    /**
     * @notice Enhanced burning mechanism with total supply check
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) public virtual override nonReentrant {
        uint256 senderBalance = balanceOf(msg.sender);
        if (amount == 0 || senderBalance < amount) {
            revert InvalidBurnAmount(amount, senderBalance);
        }

        uint256 currentSupply = totalSupply();
        if (currentSupply - amount > _totalMinted) {
            revert InvalidBurnAmount(amount, currentSupply);
        }
        
        super.burn(amount);
        emit TokensBurned(msg.sender, amount);
    }

    /**
     * @notice Mint tokens with advanced controls and total supply cap
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) public nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        
        MinterConfig storage config = _minterConfigs[msg.sender];
        if (!config.canMint) revert UnauthorizedTransfer(msg.sender);
        
        uint256 remainingAllowance = config.maxMintAmount - config.mintedAmount;
        if (amount == 0 || amount > remainingAllowance) {
            revert InvalidMintAmount(amount, remainingAllowance);
        }

        uint256 remainingSupply = MAX_SUPPLY - _totalMinted;
        if (amount > remainingSupply) {
            revert ExceedsMaxSupply(amount, remainingSupply);
        }

        unchecked {
            // Safe because of the checks above
            config.mintedAmount += amount;
            _totalMinted += amount;
        }
        
        _mint(to, amount);
        emit TokensMinted(msg.sender, to, amount);
    }

    /**
     * @notice Grant initial liquidity transfer rights
     * @param account Address to grant rights
     */
    function grantInitialLiquidityTransferRights(address account) external {
        if (account == address(0)) revert ZeroAddress();
        if (_transfersEnabled) revert TransfersAlreadyEnabled();
        if (msg.sender != initialLiquidityManager) revert UnauthorizedTransfer(msg.sender);
        
        _initialLiquidityTransferRights[account] = true;
        emit InitialLiquidityTransferRightsGranted(account);
    }

    /**
     * @notice Enable public transfers
     */
    function enableTransfers() external {
        if (_transfersEnabled) revert TransfersAlreadyEnabled();
        if (msg.sender != initialLiquidityManager) revert UnauthorizedTransfer(msg.sender);
        
        _transfersEnabled = true;
        emit TransfersEnabled(msg.sender, block.timestamp);
    }

    /**
     * @notice Add a minter with configurable mint limits
     * @param account Minter address
     * @param maxMintAmount Maximum allowed minting amount
     */
    function addMinter(address account, uint256 maxMintAmount) external onlyOwner {
        if (account == address(0)) revert ZeroAddress();
        
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
        if (account == address(0)) revert ZeroAddress();
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
            revert TransfersNotEnabled(sender);
        }
    }
}