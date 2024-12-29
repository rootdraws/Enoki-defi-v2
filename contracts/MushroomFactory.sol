// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./MushroomNFT.sol";
import "./MushroomLib.sol";

// File Modernized by Claude.AI Sonnet on 12/29/24.

/**
* @title MushroomFactory
* @notice Manages creation and attributes of Mushroom NFTs
* @dev Supports species-specific NFT minting with controlled randomization
*/
contract MushroomFactory is Ownable, ReentrancyGuard {
   using SafeERC20 for IERC20;
   using MushroomLib for MushroomLib.MushroomData;
   using MushroomLib for MushroomLib.MushroomType;

   /**
    * @notice Emitted when a mushroom is grown
    * @param recipient Address receiving the mushroom
    * @param tokenId Token ID of the minted mushroom
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
    * @notice Error thrown when recipient address is invalid
    */
   error InvalidRecipient(address recipient);

   /**
    * @notice Error thrown when token address is invalid
    */
   error InvalidTokenAddress(address token);

   /**
    * @notice Error thrown when mushroom amount exceeds species limit
    */
   error ExceedsSpeciesLimit(uint256 requested, uint256 available);

   /**
    * @notice Error thrown when attempting to collect protected token
    */
   error ProtectedToken(address token);

   /**
    * @notice Error thrown when lifespan range is invalid
    */
   error InvalidLifespanRange(uint256 min, uint256 max);

   /// @notice Core token contract references
   IERC20 public immutable sporeToken;
   MushroomNFT public immutable mushroomNft;

   /// @notice Minting configuration
   uint256 public immutable costPerMushroom;
   uint256 public immutable mySpecies;

   /// @notice Counter for randomization
   uint256 private _spawnCount;

   /**
    * @notice Configures the factory
    * @param _sporeToken SPORE token contract
    * @param _mushroomNft Mushroom NFT contract
    * @param _sporePool Initial owner address
    * @param _costPerMushroom Cost to mint each mushroom
    * @param _mySpecies Factory's specific species
    */
   constructor(
       IERC20 _sporeToken,
       MushroomNFT _mushroomNft,
       address _sporePool,
       uint256 _costPerMushroom,
       uint256 _mySpecies
   ) Ownable(_sporePool) {
       if (address(_sporeToken) == address(0)) {
           revert InvalidTokenAddress(address(_sporeToken));
       }
       if (address(_mushroomNft) == address(0)) {
           revert InvalidTokenAddress(address(_mushroomNft));
       }
       
       sporeToken = _sporeToken;
       mushroomNft = _mushroomNft;
       costPerMushroom = _costPerMushroom;
       mySpecies = _mySpecies;
   }

   /**
    * @notice Generates pseudo-random lifespan
    * @param minLifespan Minimum lifespan value
    * @param maxLifespan Maximum lifespan value
    * @return Random lifespan value within range
    */
   function _generateMushroomLifespan(
       uint256 minLifespan, 
       uint256 maxLifespan
   ) internal returns (uint256) {
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
    * @notice Gets remaining mintable mushrooms for species
    * @return Number of mushrooms available to mint
    */
   function getRemainingMintableForMySpecies() public view returns (uint256) {
       return mushroomNft.getRemainingMintableForSpecies(mySpecies);
   }

   /**
    * @notice Mints multiple mushrooms
    * @param recipient Recipient address
    * @param numMushrooms Number to mint
    */
   function growMushrooms(
       address recipient, 
       uint256 numMushrooms
   ) external nonReentrant onlyOwner {
       if (recipient == address(0)) {
           revert InvalidRecipient(recipient);
       }

       uint256 remaining = getRemainingMintableForMySpecies();
       if (remaining < numMushrooms) {
           revert ExceedsSpeciesLimit(numMushrooms, remaining);
       }

       MushroomLib.MushroomType memory species = mushroomNft.getSpecies(mySpecies);

       for (uint256 i = 0; i < numMushrooms;) {
           uint256 nextId = mushroomNft.totalSupply() + 1;
           uint256 lifespan = _generateMushroomLifespan(
               species.minLifespan, 
               species.maxLifespan
           );
           
           mushroomNft.mint(recipient, nextId, mySpecies, lifespan);
           emit MushroomGrown(recipient, nextId, mySpecies, lifespan);

           unchecked {
               i++;
           }
       }
   }

   /**
    * @notice Recovers accidentally sent tokens
    * @param token Token address to recover
    * @param amount Amount to recover
    */
   function collectDust(
       IERC20 token, 
       uint256 amount
   ) external onlyOwner {
       if (token == sporeToken) {
           revert ProtectedToken(address(token));
       }
       token.safeTransfer(owner(), amount);
   }

   /**
    * @notice Returns current spawn count
    */
   function spawnCount() external view returns (uint256) {
       return _spawnCount;
   }
}