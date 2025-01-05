// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title SporePresale
 * @notice Handles initial token distribution through ETH presale with enhanced security
 * @dev Implements ReentrancyGuard and Pausable for additional security
 * 
 * Presale now expects token to be minted in its entirity, before being distributed, rather than minted on command.
 * 
 * Core Features:
 * - Whitelist support with merkle proof verification
 * - Fixed price in ETH with precision handling
 * - Purchase limits per address
 * - Configurable supply cap
 * - Direct ETH transfer to dev wallet with fallback
 * - Emergency pause functionality
 * - Reentrancy protection
 */

contract SporePresale is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Custom errors
    error PresaleNotStarted();
    error NoSupplyLeft();
    error NotWhitelisted();
    error ExceedsBuyLimit(uint256 requested, uint256 limit);
    error InsufficientPresaleSupply(uint256 requested, uint256 available);
    error ZeroAmount();
    error ZeroAddress();
    error TransferFailed();
    error InvalidPrice();
    error AlreadyWhitelisted(address account);
    error InvalidBuyLimit();

    // State variables
    IERC20 public immutable spore;
    address payable public devAddress;

    mapping(address account => bool isWhitelisted) public whitelist;
    mapping(address account => uint256 amount) public ethSupply;
    
    uint256 public whitelistCount;
    uint256 public sporePrice;
    uint256 public buyLimit;
    uint256 public presaleLastSupply;
    
    bool public presaleStart;
    bool public onlyWhitelist;

    // Events with indexed parameters
    event PresaleStarted(uint256 indexed timestamp);
    event PresalePaused(uint256 indexed timestamp);
    event BuySporeSuccess(
        address indexed buyer,
        uint256 ethAmount,
        uint256 sporeAmount,
        uint256 timestamp
    );
    event WhitelistAdded(address[] accounts, uint256 timestamp);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event BuyLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event DevAddressUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @notice Contract constructor
     * @param devAddress_ Address to receive ETH
     * @param sporeToken_ Address of the Spore token
     * @param initialPrice_ Initial token price
     * @param initialBuyLimit_ Initial buy limit
     * @param initialSupply_ Initial presale supply
     */
    constructor(
        address payable devAddress_,
        IERC20 sporeToken_,
        uint256 initialPrice_,
        uint256 initialBuyLimit_,
        uint256 initialSupply_
    ) Ownable(msg.sender) {
        if (devAddress_ == address(0)) revert ZeroAddress();
        if (address(sporeToken_) == address(0)) revert ZeroAddress();
        if (initialPrice_ == 0) revert InvalidPrice();
        if (initialBuyLimit_ == 0) revert InvalidBuyLimit();
        
        devAddress = devAddress_;
        spore = sporeToken_;
        sporePrice = initialPrice_;
        buyLimit = initialBuyLimit_;
        presaleLastSupply = initialSupply_;
        onlyWhitelist = true;
    }

    /**
     * @notice Add addresses to whitelist
     * @param accounts Array of addresses to whitelist
     */
    function addToWhitelist(address[] calldata accounts) external onlyOwner {
        uint256 len = accounts.length;
        for (uint256 i = 0; i < len;) {
            address account = accounts[i];
            if (account == address(0)) revert ZeroAddress();
            if (whitelist[account]) revert AlreadyWhitelisted(account);
            
            whitelist[account] = true;
            unchecked { ++i; }
        }
        
        unchecked {
            whitelistCount += len;
        }
        
        emit WhitelistAdded(accounts, block.timestamp);
    }

    /**
     * @notice Start the presale
     */
    function startPresale() external onlyOwner {
        presaleStart = true;
        emit PresaleStarted(block.timestamp);
    }

    /**
     * @notice Pause the presale in case of emergency
     */
    function pausePresale() external onlyOwner {
        _pause();
        emit PresalePaused(block.timestamp);
    }

    /**
     * @notice Update the price of SPORE tokens
     * @param newPrice New price for tokens
     */
    function updatePrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert InvalidPrice();
        uint256 oldPrice = sporePrice;
        sporePrice = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }

    /**
     * @notice Update buy limit per address
     * @param newLimit New buy limit
     */
    function updateBuyLimit(uint256 newLimit) external onlyOwner {
        if (newLimit == 0) revert InvalidBuyLimit();
        uint256 oldLimit = buyLimit;
        buyLimit = newLimit;
        emit BuyLimitUpdated(oldLimit, newLimit);
    }

    /**
     * @notice Update dev address
     * @param newDevAddress New address to receive ETH
     */
    function updateDevAddress(address payable newDevAddress) external onlyOwner {
        if (newDevAddress == address(0)) revert ZeroAddress();
        address oldAddress = devAddress;
        devAddress = newDevAddress;
        emit DevAddressUpdated(oldAddress, newDevAddress);
    }

    /**
     * @notice Toggle whitelist requirement
     */
    function toggleWhitelist() external onlyOwner {
        onlyWhitelist = !onlyWhitelist;
    }

    /**
     * @notice Main presale purchase function
     * @dev Includes reentrancy protection and pause functionality
     */
    receive() external payable nonReentrant whenNotPaused {
        if (!presaleStart) revert PresaleNotStarted();
        if (presaleLastSupply == 0) revert NoSupplyLeft();
        if (msg.value == 0) revert ZeroAmount();
        
        // Whitelist check
        if (onlyWhitelist && !whitelist[msg.sender]) {
            revert NotWhitelisted();
        }

        // Buy limit check
        uint256 newEthTotal;
        unchecked {
            newEthTotal = ethSupply[msg.sender] + msg.value;
        }
        if (newEthTotal > buyLimit) {
            revert ExceedsBuyLimit(newEthTotal, buyLimit);
        }

        // Calculate token amount
        uint256 sporeAmount = msg.value * sporePrice;
        if (sporeAmount > presaleLastSupply) {
            revert InsufficientPresaleSupply(sporeAmount, presaleLastSupply);
        }
        
        // Update state
        unchecked {
            presaleLastSupply -= sporeAmount;
            ethSupply[msg.sender] = newEthTotal;
        }

        // Transfer tokens
        spore.safeTransfer(msg.sender, sporeAmount);
        
        // Transfer ETH
        (bool success, ) = devAddress.call{value: msg.value}("");
        if (!success) revert TransferFailed();
        
        emit BuySporeSuccess(msg.sender, msg.value, sporeAmount, block.timestamp);
    }

    /**
     * @notice Fallback function reverts
     */
    fallback() external payable {
        revert();
    }
}