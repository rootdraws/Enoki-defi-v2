// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "../../MushroomNFT.sol";
import "./IMetadataAdapter.sol";
import "./BaseMetadataAdapter.sol";

// File Modernized by Claude.AI Sonnet on 12/29/24.

contract MushroomAdapter is 
    Initializable, 
    ReentrancyGuardUpgradeable,
    BaseMetadataAdapter {

   using MushroomLib for MushroomLib.MushroomData;
   using MushroomLib for MushroomLib.MushroomType;

   /// @dev Reference to the main MushroomNFT contract
   MushroomNFT private immutable _mushroomNft;

   /**
    * @dev Error thrown when NFT contract address is invalid
    */
   error InvalidNFTContract(address nftContract);

   /**
    * @dev Error thrown when forwarder address is invalid
    */
   error InvalidForwarder(address forwarder);

   /**
    * @dev Error thrown when lifespan update fails
    */
   error LifespanUpdateFailed(uint256 tokenId, uint256 lifespan);

   /// @custom:oz-upgrades-unsafe-allow constructor
   constructor() {
       _disableInitializers();
   }

   /**
    * @notice Initializes the contract
    * @param nftContract_ Address of the MushroomNFT contract
    * @param forwardActionsFrom_ Address authorized to modify lifespans
    */
   function initialize(
       address nftContract_,
       address forwardActionsFrom_
   ) external initializer {
       if (nftContract_ == address(0)) revert InvalidNFTContract(nftContract_);
       if (forwardActionsFrom_ == address(0)) revert InvalidForwarder(forwardActionsFrom_);
       
       __ReentrancyGuard_init();
       
       _mushroomNft = MushroomNFT(nftContract_);
       _grantRole(LIFESPAN_MODIFIER_ROLE, forwardActionsFrom_);
       _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
   }

   /**
    * @inheritdoc IMetadataAdapter
    */
   function getMushroomData(
       uint256 index,
       bytes calldata
   ) external view override returns (MushroomLib.MushroomData memory) {
       return _mushroomNft.getMushroomData(index);
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
    * @dev Internal implementation of lifespan update
    */
   function _setMushroomLifespan(
       uint256 index,
       uint256 lifespan,
       bytes calldata
   ) internal override nonReentrant {
       try _mushroomNft.setMushroomLifespan(index, lifespan) {
           // Success case handled by parent contract's event emission
       } catch {
           revert LifespanUpdateFailed(index, lifespan);
       }
   }

   /**
    * @notice Returns version number of the contract
    */
   function version() external pure returns (uint256) {
       return 1;
   }

   /**
    * @notice Checks if the contract is healthy
    */
   function isHealthy() external view returns (bool) {
       return address(_mushroomNft) != address(0);
   }
}