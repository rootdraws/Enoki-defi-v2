// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "../../MushroomNFT.sol";
import "./IMetadataAdapter.sol";
import "./BaseMetadataAdapter.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title MushroomAdapter
 * @notice Adapter for MushroomNFT with factory-controlled lifespans
 * @dev Implements read-only functionality for mushroom metadata
 */

contract MushroomAdapter is 
    Initializable, 
    ReentrancyGuardUpgradeable,
    BaseMetadataAdapter {

   using MushroomLib for MushroomLib.MushroomData;
   using MushroomLib for MushroomLib.MushroomType;

   /// @dev Reference to the main MushroomNFT contract
   MushroomNFT public immutable mushroomNft;

   /// @dev Events for operations
   event UnsupportedOperation(string reason);

   /**
    * @dev Custom errors
    */
   error InvalidNFTContract(address nftContract);
   error InvalidForwarder(address forwarder);
   error TokenNotFound(uint256 tokenId);
   error LifespanModificationNotSupported();

   /**
    * @notice Sets up the adapter with NFT contract
    * @param nftContract_ Address of the MushroomNFT contract
    */
   constructor(address nftContract_) {
       if (nftContract_ == address(0)) revert InvalidNFTContract(nftContract_);
       mushroomNft = MushroomNFT(nftContract_);
       _disableInitializers();
   }

   /**
    * @notice Initializes the contract permissions
    * @param forwardActionsFrom_ Address of trusted forwarder (maintained for interface compatibility)
    */
   function initialize(
       address forwardActionsFrom_
   ) external initializer {
       if (forwardActionsFrom_ == address(0)) revert InvalidForwarder(forwardActionsFrom_);
       
       __ReentrancyGuard_init();
       
       // We maintain role setup for interface compatibility
       _grantRole(LIFESPAN_MODIFIER_ROLE, forwardActionsFrom_);
       _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

       emit UnsupportedOperation("Lifespan modifications not supported - Factory controlled");
   }

   /**
    * @inheritdoc IMetadataAdapter
    */
   function getMushroomData(
       uint256 index,
       bytes calldata
   ) external view override returns (MushroomLib.MushroomData memory) {
       return mushroomNft.getMushroomData(index);
   }

   /**
    * @inheritdoc IMetadataAdapter
    */
   function isStakeable(
       uint256
   ) external pure override returns (bool) {
       return true;
   }

   /**
    * @inheritdoc IMetadataAdapter
    */
   function isBurnable(
       uint256
   ) external pure override returns (bool) {
       return true;
   }

   /**
    * @dev This operation is no longer supported as lifespans are factory-controlled
    */
   function _setMushroomLifespan(
       uint256,
       uint256,
       bytes calldata
   ) internal pure override {
       revert LifespanModificationNotSupported();
   }

   /**
    * @notice Returns version number of the contract
    */
   function version() external pure returns (uint256) {
       return 2; // Incremented to reflect factory pattern
   }

   /**
    * @notice Checks if the contract is healthy
    */
   function isHealthy() external view returns (bool) {
       return address(mushroomNft) != address(0);
   }

   /**
    * @notice Get the species details for a token
    * @param tokenId Token to query
    * @return species Species configuration
    */
   function getSpeciesForToken(
       uint256 tokenId
   ) external view returns (MushroomLib.MushroomType memory) {
       MushroomLib.MushroomData memory data = mushroomNft.getMushroomData(tokenId);
       return mushroomNft.getSpecies(data.species);
   }

   /**
    * @notice Explains why lifespan modification is not supported
    * @return message Explanation of factory control
    */
   function getLifespanModificationStatus() external pure returns (string memory) {
       return "Lifespans are controlled by Factory at mint time and cannot be modified";
   }
}