// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface ISporeToken {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IMushroomFactory {
    function costPerMushroom() external view returns (uint256);
    function growMushrooms(address recipient, uint256 count) external;
}

contract MushroomMinter is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for ISporeToken;

    error InvalidAmount();
    error InsufficientSpore();
    error ZeroAddress();

    ISporeToken public immutable sporeToken;
    IMushroomFactory public immutable mushroomFactory;
    
    address public devAddress;
    address public daoAddress;
    uint256 public devShare; // Percentage with 2 decimals (e.g., 1000 = 10%)
    
    event MushroomsMinted(address indexed user, uint256 count, uint256 sporeSpent);
    event SharesUpdated(uint256 newDevShare);
    event AddressesUpdated(address newDev, address newDao);

    constructor(
        address _sporeToken,
        address _mushroomFactory,
        address _devAddress,
        address _daoAddress,
        uint256 _devShare
    ) {
        if (_sporeToken == address(0) || 
            _mushroomFactory == address(0) || 
            _devAddress == address(0) || 
            _daoAddress == address(0)) revert ZeroAddress();
        if (_devShare > 10000) revert InvalidAmount(); // Max 100%

        sporeToken = ISporeToken(_sporeToken);
        mushroomFactory = IMushroomFactory(_mushroomFactory);
        devAddress = _devAddress;
        daoAddress = _daoAddress;
        devShare = _devShare;
    }

    function mintMushrooms(uint256 count) external nonReentrant whenNotPaused {
        if (count == 0) revert InvalidAmount();

        uint256 totalCost = mushroomFactory.costPerMushroom() * count;
        if (totalCost == 0) revert InvalidAmount();

        // Calculate shares
        uint256 devAmount = (totalCost * devShare) / 10000;
        uint256 daoAmount = totalCost - devAmount;

        // Transfer SPORE from user
        sporeToken.safeTransferFrom(msg.sender, address(this), totalCost);

        // Distribute SPORE
        if (devAmount > 0) {
            sporeToken.safeTransfer(devAddress, devAmount);
        }
        sporeToken.safeTransfer(daoAddress, daoAmount);

        // Mint mushrooms
        mushroomFactory.growMushrooms(msg.sender, count);

        emit MushroomsMinted(msg.sender, count, totalCost);
    }

    // Admin functions
    function updateShares(uint256 _devShare) external onlyOwner {
        if (_devShare > 10000) revert InvalidAmount();
        devShare = _devShare;
        emit SharesUpdated(_devShare);
    }

    function updateAddresses(
        address _devAddress, 
        address _daoAddress
    ) external onlyOwner {
        if (_devAddress == address(0) || _daoAddress == address(0)) revert ZeroAddress();
        devAddress = _devAddress;
        daoAddress = _daoAddress;
        emit AddressesUpdated(_devAddress, _daoAddress);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
} 