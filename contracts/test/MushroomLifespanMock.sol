// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../MushroomLib.sol";
import {MushroomNFT} from "../MushroomNFT.sol";

// File Modernized by Claude.AI Sonnet on 12/29/24.

/**
* @title MushroomLifespanMock
* @notice Mock contract for testing mushroom lifecycle functionality
* @dev Simulates mushroom minting with randomized lifespans
*/
contract MushroomLifespanMock is 
   Initializable, 
   OwnableUpgradeable,
   ReentrancyGuardUpgradeable 
{
   using MushroomLib for MushroomLib.MushroomData;
   using MushroomLib for MushroomLib.MushroomType;

   /// @notice Counter used for lifespan randomization
   uint256 private _spawnCount;

   /**
    * @notice Emitted when a mushroom is grown
    * @param recipient Address receiving the mushroom
    * @param tokenId ID of the minted token
    * @param speciesId Species of the mushroom
    * @param lifespan Generated lifespan value
    */
   event MushroomGrown(
       address indexed recipient,
       uint256 indexed tokenId,
       uint256 indexed speciesId,
       uint256 lifespan
   );

   /**
    * @notice Error thrown when mushroom amount exceeds species limit
    * @param requested Number requested
    * @param available Number available
    */
   error ExceedsSpeciesLimit(uint256 requested, uint256 available);

   /**
    * @notice Error thrown when lifespan range is invalid
    * @param min Minimum lifespan
    * @param max Maximum lifespan
    */
   error InvalidLifespanRange(uint256 min, uint256 max);

   /**
    * @notice Error thrown when recipient is invalid
    * @param recipient The invalid address
    */
   error InvalidRecipient(address recipient);

   /// @custom:oz-upgrades-unsafe-allow constructor
   constructor() {
       _disableInitializers();
   }

   /**
    * @notice Initializes the contract
    */
   function initialize() external initializer {
       __Ownable_init(msg.sender);
       __ReentrancyGuard_init();
       _spawnCount = 0;
   }

   /**
    * @notice Generates pseudo-random lifespan between min and max values
    * @param minLifespan Minimum lifespan value
    * @param maxLifespan Maximum lifespan value
    * @return Generated lifespan value
    * @dev Uses block timestamp + spawn count for randomization
    */
   function generateMushroomLifespan(
       uint256 minLifespan,
       uint256 maxLifespan
   ) public returns (uint256) {
       if (maxLifespan <= minLifespan) {
           revert InvalidLifespanRange(minLifespan, maxLifespan);
       }

       uint256 range = maxLifespan - minLifespan;
       uint256 fromMin = uint256(
           keccak256(
               abi.encodePacked(block.timestamp + _spawnCount)
           )
       ) % range;
       
       unchecked {
           _spawnCount++;
       }

       return minLifespan + fromMin;
   }

   /**
    * @notice Gets remaining mintable mushrooms for a species
    * @param mushroomNft NFT contract address
    * @param speciesId Species to check
    * @return Number of mushrooms still mintable
    */
   function getRemainingMintableForMySpecies(
       MushroomNFT mushroomNft,
       uint256 speciesId
   ) public view returns (uint256) {
       return mushroomNft.getRemainingMintableForSpecies(speciesId);
   }

   /**
    * @notice Mints multiple mushrooms with random lifespans
    * @param mushroomNft NFT contract address
    * @param speciesId Species to mint
    * @param recipient Recipient address
    * @param numMushrooms Number of mushrooms to mint
    */
   function growMushrooms(
       MushroomNFT mushroomNft,
       uint256 speciesId,
       address recipient,
       uint256 numMushrooms
   ) external nonReentrant {
       if (recipient == address(0)) {
           revert InvalidRecipient(recipient);
       }

       uint256 remaining = getRemainingMintableForMySpecies(
           mushroomNft,
           speciesId
       );
       
       if (remaining < numMushrooms) {
           revert ExceedsSpeciesLimit(numMushrooms, remaining);
       }

       MushroomLib.MushroomType memory species = mushroomNft.getSpecies(speciesId);
       
       for (uint256 i = 0; i < numMushrooms;) {
           uint256 nextId = mushroomNft.totalSupply() + 1;
           uint256 lifespan = generateMushroomLifespan(
               species.minLifespan,
               species.maxLifespan
           );

           mushroomNft.mint(recipient, nextId, speciesId, lifespan);
           emit MushroomGrown(recipient, nextId, speciesId, lifespan);

           unchecked {
               i++;
           }
       }
   }

   /**
    * @notice Returns current spawn count
    */
   function spawnCount() external view returns (uint256) {
       return _spawnCount;
   }
}