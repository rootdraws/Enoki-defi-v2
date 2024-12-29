// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title MushroomLib
* @dev Library defining core data structures for Mushroom NFTs
* Tracks both individual mushroom data and species-level traits
*/

library MushroomLib {
   /**
    * @dev Data for an individual mushroom NFT
    * @param species ID of the mushroom's species type
    * @param strength Power/reward generation rate
    * @param lifespan How long mushroom can be used before dying
    */
   struct MushroomData {
       uint256 species;    // Species identifier 
       uint256 strength;   // Power/earning rate
       uint256 lifespan;   // Time until death/burn
   }

   /**
    * @dev Defines traits for a mushroom species
    * @param id Unique identifier for species
    * @param strength Base strength for this species
    * @param minLifespan Minimum possible lifespan
    * @param maxLifespan Maximum possible lifespan
    * @param minted Count of mushrooms minted of this species
    * @param cap Maximum allowed to be minted
    */
   struct MushroomType {
       uint256 id;           // Species ID
       uint256 strength;     // Base power level
       uint256 minLifespan;  // Shortest possible life
       uint256 maxLifespan;  // Longest possible life
       uint256 minted;       // How many exist
       uint256 cap;         // Maximum allowed
   }
}