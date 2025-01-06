// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title IModernSporeToken
 * @notice Interface for advanced ERC20 token with controlled minting and transfer mechanisms
 * @dev Extends ERC20 with EIP-2612 permit support
 */

interface IModernSporeToken is IERC20, IERC20Permit {
    // Structs
    struct MinterConfig {
        bool canMint;
        uint256 maxMintAmount;
        uint256 mintedAmount;
    }

    // Events
    event TransfersEnabled(address indexed enabler, uint256 timestamp);
    event MinterAdded(address indexed minter, uint256 maxMintAmount);
    event MinterRemoved(address indexed minter);
    event InitialLiquidityTransferRightsGranted(address indexed account);
    event TokensBurned(address indexed burner, uint256 amount);
    event TokensMinted(
        address indexed minter,
        address indexed to,
        uint256 amount
    );

    // Custom Errors
    error TransfersNotEnabled(address sender);
    error InvalidMintAmount(uint256 requested, uint256 remaining);
    error InvalidBurnAmount(uint256 amount, uint256 balance);
    error UnauthorizedTransfer(address sender);
    error TransfersAlreadyEnabled();
    error ExceedsMaxSupply(uint256 requested, uint256 remaining);
    error ZeroAddress();

    // Constants
    function MAX_SUPPLY() external pure returns (uint256);
    function decimals() external pure returns (uint8);

    // View Functions
    function initialLiquidityManager() external view returns (address);
    function transfersEnabled() external view returns (bool);

    // State-Changing Functions
    function burn(uint256 amount) external;
    
    function mint(
        address to,
        uint256 amount
    ) external;

    function grantInitialLiquidityTransferRights(
        address account
    ) external;

    function enableTransfers() external;

    function addMinter(
        address account,
        uint256 maxMintAmount
    ) external;

    function removeMinter(
        address account
    ) external;
}