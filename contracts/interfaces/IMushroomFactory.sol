// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Now that the bottom contracts are all Modernized, we need to upgrade these Interfaces
// Copy the bottom contracts, and then say, Create an interface for these please, here is the previous interface.

/**
 * @title IMushroomFactory
 * @notice Interface for mushroom NFT creation and management
 * @dev Standardizes mushroom creation across different factory implementations
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

    /**
     * @notice Thrown when requested amount exceeds available supply
     * @param requested Number requested
     * @param available Number available
     */
    error ExceedsSpeciesLimit(uint256 requested, uint256 available);

    /**
     * @notice Thrown when recipient address is invalid
     * @param recipient The invalid address
     */
    error InvalidRecipient(address recipient);

    /**
     * @notice Thrown when requested amount is invalid
     * @param amount The invalid amount
     */
    error InvalidAmount(uint256 amount);

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
     * @notice Gets remaining mintable mushrooms for factory's species
     * @return remaining Number of mushrooms still mintable
     */
    function getRemainingMintableForSpecies() external view returns (uint256);

    /**
     * @notice Gets the species ID this factory creates
     * @return Species identifier
     */
    function getFactorySpecies() external view returns (uint256);
}