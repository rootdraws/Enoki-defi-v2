// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// File Modernized by Claude.AI Sonnet on 12/29/24.

/**
 * @title IMushroomFactory
 * @notice Interface for minting and managing mushroom NFTs
 * @dev Handles mushroom creation and species limitations
 */
interface IMushroomFactory {
    /**
     * @notice Emitted when new mushrooms are created
     * @param recipient Address receiving the mushrooms
     * @param numMushrooms Number of mushrooms created
     * @param speciesId ID of the mushroom species
     */
    event MushroomsGrown(
        address indexed recipient,
        uint256 indexed numMushrooms,
        uint256 indexed speciesId
    );

    /**
     * @notice Thrown when requested mushroom amount exceeds limits
     * @param requested Number of mushrooms requested
     * @param available Number of mushrooms available
     */
    error ExceedsSpeciesLimit(uint256 requested, uint256 available);

    /**
     * @notice Thrown when recipient address is invalid
     * @param recipient The invalid recipient address
     */
    error InvalidRecipient(address recipient);

    /**
     * @notice Thrown when mushroom amount is invalid
     * @param amount The invalid amount
     */
    error InvalidMushroomAmount(uint256 amount);

    /**
     * @notice Returns the cost to mint each mushroom
     * @return Cost per mushroom in base currency
     */
    function costPerMushroom() external view returns (uint256);

    /**
     * @notice Checks remaining mintable mushrooms for the caller's species
     * @param numMushrooms Number of mushrooms to check against limit
     * @return remaining Number of mushrooms that can still be minted
     */
    function getRemainingMintableForMySpecies(
        uint256 numMushrooms
    ) external view returns (uint256 remaining);

    /**
     * @notice Creates new mushroom NFTs for a recipient
     * @param recipient Address to receive the mushrooms
     * @param numMushrooms Number of mushrooms to create
     * @dev Reverts if species limit would be exceeded
     */
    function growMushrooms(
        address recipient,
        uint256 numMushrooms
    ) external;

    /**
     * @notice Returns the maximum mushrooms per species
     * @return Maximum number of mushrooms allowed per species
     */
    function maxMushroomsPerSpecies() external view returns (uint256);
}