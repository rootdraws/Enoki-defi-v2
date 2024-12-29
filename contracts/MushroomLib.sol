// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MushroomLib
 * @notice Core data structures for Mushroom NFT ecosystem
 * @dev Defines individual mushroom and species-level traits
 */
library MushroomLib {
    /**
     * @notice Represents an individual Mushroom NFT's core attributes
     * @param species Unique identifier for mushroom species
     * @param strength Power rating or reward generation rate
     * @param lifespan Duration before mushroom becomes unusable
     */
    struct MushroomData {
        uint256 species;    // Species identifier 
        uint256 strength;   // Power/earning rate
        uint256 lifespan;   // Time until death/burn
    }

    /**
     * @notice Defines comprehensive traits for a specific Mushroom species
     * @param id Unique species identifier
     * @param strength Base power level for the species
     * @param minLifespan Shortest possible lifespan
     * @param maxLifespan Longest possible lifespan
     * @param minted Total number of mushrooms minted in this species
     * @param cap Maximum number of mushrooms allowed for this species
     */
    struct MushroomType {
        uint256 id;           // Species ID
        uint256 strength;     // Base power level
        uint256 minLifespan;  // Shortest possible life
        uint256 maxLifespan;  // Longest possible life
        uint256 minted;       // Existing mushroom count
        uint256 cap;          // Maximum allowed mintable
    }

    /**
     * @notice Checks if a mushroom can be minted within species cap
     * @param species The mushroom species to check
     * @return Whether additional mushrooms can be minted
     */
    function canMintMore(MushroomType storage species) internal view returns (bool) {
        return species.minted < species.cap;
    }

    /**
     * @notice Calculates remaining mintable mushrooms for a species
     * @param species The mushroom species to check
     * @return Number of mushrooms still available to mint
     */
    function remainingMintable(MushroomType storage species) internal view returns (uint256) {
        return species.cap > species.minted 
            ? species.cap - species.minted 
            : 0;
    }

    /**
     * @notice Validates mushroom data integrity
     * @param mushroom The mushroom data to validate
     * @return Whether the mushroom data is valid
     */
    function isValidMushroom(MushroomData memory mushroom) internal pure returns (bool) {
        return mushroom.species > 0 && 
               mushroom.strength > 0 && 
               mushroom.lifespan > 0;
    }
}