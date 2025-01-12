// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// File Processed by Claude.AI Sonnet on 1/11/25.

// SPORE VESTING CONTRACT | FACTORY INSTANCE
// This is a vesting contract for the Spore ecosystem. It is used to vest tokens for the vaults.
// This contract is paired with the SporeVault contract, and launched as a factory instance.

contract SporeVesting is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant EPOCH_DURATION = 21 days;
    uint256 public constant RESTART_COST = 0.01 ether;

    // State variables
    address public vault;
    uint256 public currentEpochStart;
    string public name;
    string public symbol;
    
    // Token tracking
    mapping(address => bool) public trackedTokens;
    address[] public tokenList;

    // Errors
    error NotVault();
    error NoVestedTokens();
    error InsufficientPayment();
    error EpochNotComplete();
    error ETHTransferFailed();

    // Events
    event TokensReceived(address token, uint256 amount, uint256 timestamp);
    event TokensReleased(address token, uint256 amount, uint256 timestamp);
    event EpochRestarted(uint256 timestamp, address restarter);
    event AllTokensReleased(uint256 tokenCount, uint256 timestamp);
    event TokenTracked(address token);
    event TokenUntracked(address token);
    event VaultUpdated(address newVault);

    // Constructor
    constructor() {
        _disableInitializers();
    }

    // Initialize the vesting contract
    function initialize(
        address _vault,
        string memory _name,
        string memory _symbol
    ) external initializer {
        __Ownable_init(msg.sender);
        vault = _vault;
        name = _name;
        symbol = _symbol;
        currentEpochStart = block.timestamp;
    }

    // Deposit tokens to be vested
    function depositTokens(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Add token to tracking if not already tracked
        if (!trackedTokens[token]) {
            trackedTokens[token] = true;
            tokenList.push(token);
            emit TokenTracked(token);
        }

        emit TokensReceived(token, amount, block.timestamp);
    }

    // Restart the epoch with ETH payment
    function restartEpoch() external payable {
        if (msg.value < RESTART_COST) revert InsufficientPayment();
        
        // Only allow restart if current epoch is complete
        if (block.timestamp < currentEpochStart + EPOCH_DURATION) {
            revert EpochNotComplete();
        }
        
        currentEpochStart = block.timestamp;
        
        // Send ETH to vault
        (bool success, ) = vault.call{value: msg.value}("");
        if (!success) revert ETHTransferFailed();
        
        emit EpochRestarted(block.timestamp, msg.sender);
    }

    // Release all vested tokens
    function releaseAllVested() external {
        uint256 totalReleased = 0;
        
        for (uint256 i = 0; i < tokenList.length; i++) {
            address token = tokenList[i];
            uint256 vestedAmount = _calculateVestedAmount(token);
            
            if (vestedAmount > 0) {
                IERC20(token).safeTransfer(vault, vestedAmount);
                emit TokensReleased(token, vestedAmount, block.timestamp);
                totalReleased++;
                
                // If balance is now 0, we can untrack the token
                if (IERC20(token).balanceOf(address(this)) == 0) {
                    _untrackToken(i);
                    i--; // Adjust index since we removed an element
                }
            }
        }
        
        if (totalReleased == 0) revert NoVestedTokens();
        
        emit AllTokensReleased(totalReleased, block.timestamp);
    }

    // Calculate amount of tokens that have vested
    function _calculateVestedAmount(address token) internal view returns (uint256) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance == 0) return 0;

        uint256 timePassed = block.timestamp - currentEpochStart;
        if (timePassed >= EPOCH_DURATION) {
            return balance;
        }

        return (balance * timePassed) / EPOCH_DURATION;
    }

    // Admin function to manually track tokens
    function addTokenTracking(address token) external onlyOwner {
        if (!trackedTokens[token]) {
            trackedTokens[token] = true;
            tokenList.push(token);
            emit TokenTracked(token);
        }
    }

    // Helper function to untrack tokens
    function _untrackToken(uint256 index) internal {
        address token = tokenList[index];
        
        // Remove from array by swapping with last element and popping
        tokenList[index] = tokenList[tokenList.length - 1];
        tokenList.pop();
        
        // Update mapping
        trackedTokens[token] = false;
        
        emit TokenUntracked(token);
    }

    // Admin function to update vault
    function setVault(address newVault) external onlyOwner {
        vault = newVault;
        emit VaultUpdated(newVault);
    }

    // View functions
    function vestedAmount(address token) external view returns (uint256) {
        return _calculateVestedAmount(token);
    }

    function getTrackedTokens() external view returns (address[] memory) {
        return tokenList;
    }

    // Allow contract to receive ETH
    receive() external payable {}
} 