// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// File Modernized by Claude.AI Sonnet on 12/29/24.

/**
* @title MushroomLib
* @notice Core data structures and validation for Mushroom NFT ecosystem
* @dev Defines mushroom traits and species configuration
*/
library MushroomLib {
   /**
    * @notice Error thrown when species cap is exceeded
    */
   error SpeciesCapExceeded(uint256 speciesId, uint256 cap);

   /**
    * @notice Error thrown when mushroom data is invalid
    */
   error InvalidMushroomData();

   /**
    * @notice Error thrown when species data is invalid
    */ 
   error InvalidSpeciesData();

   /**
    * @notice Core attributes of a Mushroom NFT
    * @param species Unique identifier for mushroom species
    * @param strength Power rating for reward generation
    * @param lifespan Duration until unusable
    */
   struct MushroomData {
       uint256 species;
       uint256 strength;
       uint256 lifespan;
   }

   /**
    * @notice Configuration for a Mushroom species
    * @param id Unique species identifier
    * @param strength Base power level
    * @param minLifespan Minimum possible lifespan
    * @param maxLifespan Maximum possible lifespan
    * @param minted Current minted count
    * @param cap Maximum allowed supply
    */
   struct MushroomType {
       uint256 id;
       uint256 strength;
       uint256 minLifespan;
       uint256 maxLifespan;
       uint256 minted;
       uint256 cap;
   }

   /**
    * @notice Checks if more mushrooms can be minted
    * @param species Species to check
    * @return True if minting is allowed
    */
   function canMintMore(
       MushroomType storage species
   ) internal view returns (bool) {
       if (!_isValidSpecies(species)) {
           revert InvalidSpeciesData();
       }
       return species.minted < species.cap;
   }

   /**
    * @notice Gets remaining mintable amount
    * @param species Species to check
    * @return Remaining mintable amount
    */
   function remainingMintable(
       MushroomType storage species
   ) internal view returns (uint256) {
       if (!_isValidSpecies(species)) {
           revert InvalidSpeciesData();
       }

       return species.cap > species.minted 
           ? species.cap - species.minted 
           : 0;
   }

   /**
    * @notice Validates mushroom data
    * @param mushroom Mushroom to validate
    * @return True if data is valid
    */
   function isValidMushroom(
       MushroomData memory mushroom
   ) internal pure returns (bool) {
       return mushroom.species > 0 && 
              mushroom.strength > 0 && 
              mushroom.lifespan > 0;
   }

   /**
    * @notice Internal species validation
    * @param species Species to validate
    * @return True if valid
    */
   function _isValidSpecies(
       MushroomType storage species
   ) private view returns (bool) {
       return species.id > 0 &&
              species.strength > 0 &&
              species.minLifespan > 0 &&
              species.maxLifespan > species.minLifespan &&
              species.cap > 0;
   }

   /**
    * @notice Gets species stats
    * @param species Species to get stats for
    * @return id Species ID
    * @return minted Amount minted
    * @return available Amount remaining
    */
   function getSpeciesStats(
       MushroomType storage species
   ) internal view returns (
       uint256 id,
       uint256 minted,
       uint256 available
   ) {
       if (!_isValidSpecies(species)) {
           revert InvalidSpeciesData();
       }

       return (
           species.id,
           species.minted,
           remainingMintable(species)
       );
   }

   /**
    * @notice Validates and formats mushroom data
    * @param data Raw mushroom data
    * @return Validated mushroom data
    */
   function validateAndFormat(
       MushroomData memory data
   ) internal pure returns (MushroomData memory) {
       if (!isValidMushroom(data)) {
           revert InvalidMushroomData();
       }
       return data;
   }
}