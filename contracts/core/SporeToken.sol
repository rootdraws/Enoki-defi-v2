// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// File Processed by Claude.AI Sonnet on 1/11/25.

// $SPORE Token Contract
// This Contract holds a fixed supply of SPORE tokens.
// sporeEmission() is used to distribute 10% of SPORE tokens held in contract to a Vault
// transferOwnership() is used to transfer ownership of the contract to a new address, and the new owner must also use acceptOwnership() to take ownership of the contract.

contract SporeToken is 
    ERC20, 
    ERC20Permit, 
    ERC20Burnable, 
    Ownable2Step,
    ReentrancyGuard 
{
    // Errors
    error TransfersNotEnabled(address sender);
    error InvalidBurnAmount(uint256 amount, uint256 balance);
    error UnauthorizedTransfer(address sender);
    error TransfersAlreadyEnabled();
    error ZeroAddress();
    error PresaleAlreadySet();
    error PresaleNotSet();
    error NotRegisteredVault();

    // State Variables
    bool private _transfersEnabled;
    address private _presaleAddress;  // New variable for presale address

    // Mappings
    mapping(address account => bool hasRights) private _initialLiquidityTransferRights;

    // Supply
    uint256 public constant TOTAL_SUPPLY = 1_000_000 * 10**18; // 1 million tokens

    // Events
    event TransfersEnabled(address indexed enabler, uint256 timestamp);
    event TokensBurned(address indexed burner, uint256 amount);

    // Constructor
    constructor() ERC20("Mycelia", "SPORE") ERC20Permit("Mycelia") Ownable(msg.sender) {
        // Only grant rights to owner
        _initialLiquidityTransferRights[msg.sender] = true;

        // Mint total supply to contract
        _mint(address(this), TOTAL_SUPPLY);
    }

    // This Contract Transfers SPORE tokens elsewhere.
    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override nonReentrant returns (bool) {
        _checkTransferEligibility(msg.sender);
        return super.transfer(recipient, amount);
    }

    // Another Contract can transfer SPORE tokens if they have transfer rights.
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override nonReentrant returns (bool) {
        _checkTransferEligibility(sender);
        return super.transferFrom(sender, recipient, amount);
    }

    // Contract Distributes 10% of SPORE tokens held in contract to a specific address.
    function sporeEmission() external {
        // Get vault's vesting contract from factory
        address vesting = sporeVaultFactory.getVaultVesting(msg.sender);
        if (vesting == address(0)) revert NotRegisteredVault();
        
        // Simple 10% emission to vesting contract
        uint256 amount = balanceOf(address(this)) / 10;
        _transfer(address(this), vesting, amount);
        
        // Notify vesting contract
        SporeVesting(vesting).receiveEmission();
    }

    // Burn SPORE tokens
    function burn(uint256 amount) public virtual override nonReentrant {
        uint256 senderBalance = balanceOf(msg.sender);
        if (amount == 0 || senderBalance < amount) {
            revert InvalidBurnAmount(amount, senderBalance);
        }
        
        super.burn(amount);
        emit TokensBurned(msg.sender, amount);
    }

    // Enable SPORE Transfers by Public
    function enableTransfers() external onlyOwner {
        if (_transfersEnabled) revert TransfersAlreadyEnabled();
        
        _transfersEnabled = true;
        emit TransfersEnabled(msg.sender, block.timestamp);
    }

    // Pre-Transfer Check
    function _checkTransferEligibility(address sender) private view {
        if (_transfersEnabled) return;
        if (!_initialLiquidityTransferRights[sender]) {
            revert TransfersNotEnabled(sender);
        }
    }

    // Sets the presale contract address
    function setPresaleAddress(address presaleAddress) external onlyOwner {
        if (presaleAddress == address(0)) revert ZeroAddress();
        if (_presaleAddress != address(0)) revert PresaleAlreadySet();
        
        _presaleAddress = presaleAddress;
        _initialLiquidityTransferRights[presaleAddress] = true;  // Grant transfer rights
    }

    // Allocates 50% of total supply to presale contract
    function allocatePresale() external onlyOwner {
        if (_presaleAddress == address(0)) revert PresaleNotSet();
        
        uint256 presaleAmount = TOTAL_SUPPLY / 2;  // 50% of total supply
        _transfer(address(this), _presaleAddress, presaleAmount);
    }
}