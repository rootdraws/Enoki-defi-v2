// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./OnlyEOA.sol";

// File Processed by Claude.AI Sonnet on 1/11/25.

// $SPORE Token Contract
// SPORE tokens are sold at a fixed Price during the presale
// SPORE tokens must be minted and transferred to this contract before the presale starts.

contract SporePresale is Ownable2Step, ReentrancyGuard, OnlyEOAGuard {
    using SafeERC20 for IERC20;

    // Custom errors
    error PresaleNotStarted();
    error NoSupplyLeft();
    error InsufficientPresaleSupply(uint256 requested, uint256 available);
    error ZeroAmount();
    error ZeroAddress();
    error TransferFailed();

    // State variables
    IERC20 public immutable spore;
    uint256 public immutable sporePrice;
    address payable public devAddress;

    uint256 public presaleLastSupply;
    
    bool public presaleStart;

    // Events with indexed parameters
    event PresaleStarted(uint256 indexed timestamp);
    event BuySporeSuccess(
        address indexed buyer,
        uint256 ethAmount,
        uint256 sporeAmount,
        uint256 timestamp
    );
    event DevAddressUpdated(address indexed oldAddress, address indexed newAddress);

    constructor(
        address payable devAddress_,
        IERC20 sporeToken_,
        uint256 initialPrice_,
        uint256 initialSupply_
    ) Ownable(msg.sender) {
        if (devAddress_ == address(0)) revert ZeroAddress();
        if (address(sporeToken_) == address(0)) revert ZeroAddress();
        if (initialPrice_ == 0) revert InvalidPrice();
        
        devAddress = devAddress_;
        spore = sporeToken_;
        sporePrice = initialPrice_;
        presaleLastSupply = initialSupply_;
    }

    // Start the presale
    function startPresale() external onlyOwner {
        presaleStart = true;
        emit PresaleStarted(block.timestamp);
    }

    // Update the Address that receives ETH
    function updateDevAddress(address payable newDevAddress) external onlyOwner {
        if (newDevAddress == address(0)) revert ZeroAddress();
        address oldAddress = devAddress;
        devAddress = newDevAddress;
        emit DevAddressUpdated(oldAddress, newDevAddress);
    }

    // Main presale purchase function
    receive() external payable nonReentrant onlyEOA {
        if (!presaleStart) revert PresaleNotStarted();
        if (presaleLastSupply == 0) revert NoSupplyLeft();
        if (msg.value == 0) revert ZeroAmount();
        
        // Calculate token amount
        uint256 sporeAmount = msg.value * sporePrice;
        if (sporeAmount > presaleLastSupply) {
            revert InsufficientPresaleSupply(sporeAmount, presaleLastSupply);
        }
        
        // Update state
        unchecked {
            presaleLastSupply -= sporeAmount;
        }

        // Transfer tokens
        spore.safeTransfer(msg.sender, sporeAmount);
        
        // Transfer ETH
        (bool success, ) = devAddress.call{value: msg.value}("");
        if (!success) revert TransferFailed();
        
        emit BuySporeSuccess(msg.sender, msg.value, sporeAmount, block.timestamp);
    }

    // Fallback function
    fallback() external payable {
        revert();
    }
}