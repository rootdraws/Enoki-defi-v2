// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../MushroomNFT.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title IMushroomFactory
 * @notice Interface for advanced mushroom NFT creation and management
 */

interface IMushroomFactory {
    /**
     * @notice Emitted when mushrooms are created
     * @param recipient Address receiving the mushrooms
     * @param tokenIds Array of created token IDs
     * @param speciesId Species of the mushrooms
     */
    event MushroomsGrown(
        address indexed recipient,
        uint256[] tokenIds,
        uint256 indexed speciesId
    );

    // Errors
    error ExceedsSpeciesLimit(uint256 requested, uint256 available);
    error InvalidRecipient(address recipient);
    error InvalidAmount(uint256 amount);
    error InvalidTokenAddress(address token);
    error InvalidLifespanRange(uint256 min, uint256 max);
    error ProtectedToken(address token);

    // View Functions
    function sporeToken() external view returns (IERC20);
    function mushroomNft() external view returns (MushroomNFT);
    function costPerMushroom() external view returns (uint256);
    function getRemainingMintableForSpecies() external view returns (uint256);
    function getFactorySpecies() external view returns (uint256);
    function spawnCount() external view returns (uint256);

    /**
     * @notice Creates new mushroom NFTs
     * @param recipient Address to receive mushrooms
     * @param numMushrooms Number of mushrooms to create
     * @return tokenIds Array of created token IDs
     */
    function growMushrooms(
        address recipient,
        uint256 numMushrooms
    ) external returns (uint256[] memory tokenIds);

    /**
     * @notice Recovers accidentally sent tokens
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function collectDust(
        IERC20 token,
        uint256 amount
    ) external;
}