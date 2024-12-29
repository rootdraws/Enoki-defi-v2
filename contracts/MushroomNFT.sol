// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title MushroomNFT
* @dev Implementation of Mushroom NFTs with specific metadata and functionality
* Extends ERC721UpgradeSafe with mushroom-specific traits and controls
* 
* Key Differences from Standard ERC721:
* 1. Custom metadata tracking for mushroom traits
* 2. Species management system
* 3. Role-based minting and lifespan modification
* 4. Burning mechanics with species count updates

MushroomNFT
├── ERC721 Implementation
├── Species system with traits
├── Metadata resolver integration
├── Lifespan mechanics
└── Burn functionality

MetadataResolver
├── Tracks NFT attributes
├── Species definitions
└── Lifespan management

*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERC721.sol";
import "./MushroomLib.sol";

contract MushroomNFT is ERC721UpgradeSafe, OwnableUpgradeSafe, AccessControlUpgradeSafe {
   using MushroomLib for MushroomLib.MushroomData;
   using MushroomLib for MushroomLib.MushroomType;

   // Core storage mappings
   mapping (uint256 => MushroomLib.MushroomData) public mushroomData;      // Individual mushroom traits
   mapping (uint256 => MushroomLib.MushroomType) public mushroomTypes;     // Species definitions
   mapping (uint256 => bool) public mushroomTypeExists;                    // Species existence check
   mapping (uint256 => string) public mushroomMetadataUri;                // Species metadata URIs

   // Role definitions
   bytes32 public constant LIFESPAN_MODIFIER_ROLE = keccak256("LIFESPAN_MODIFIER_ROLE");
   bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

   /**
    * @dev Initializes contract with name, symbol, and admin role
    */
   function initialize() public initializer {
       __Ownable_init_unchained();
       __AccessControl_init_unchained();
       __ERC721_init("Enoki Mushrooms", "Enoki Mushrooms");
       _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
   }

   /* ========== VIEWS ========== */

   /**
    * @dev Gets mushroom metadata for specific token
    */
   function getMushroomData(uint256 tokenId) public view returns (MushroomLib.MushroomData memory) {
       MushroomLib.MushroomData memory data = mushroomData[tokenId];
       return data;
   }

   // Additional view functions...

   /* ========== RESTRICTED FUNCTIONS ========== */

   /**
    * @dev Burns mushroom and updates species count
    */
   function burn(uint256 tokenId) public {
       require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Burnable: caller is not owner nor approved");
       _burn(tokenId);
       _clearMushroomData(tokenId);
   }

   /**
    * @dev Mints new mushroom with specific traits
    */
   function mint(address recipient, uint256 tokenId, uint256 speciesId, uint256 lifespan) public onlyMinter {
       _mintWithMetadata(recipient, tokenId, speciesId, lifespan);
   }

   /**
    * @dev Internal function to mint mushroom with metadata
    */
   function _mintWithMetadata(address recipient, uint256 tokenId, uint256 speciesId, uint256 lifespan) internal {
       require(mushroomTypeExists[speciesId], "MushroomNFT: mushroom species specified does not exist");
       MushroomLib.MushroomType storage species = mushroomTypes[speciesId];
       require(species.minted < species.cap, "MushroomNFT: minting cap reached for species");

       species.minted = species.minted.add(1);
       mushroomData[tokenId] = MushroomLib.MushroomData(speciesId, species.strength, lifespan);

       _safeMint(recipient, tokenId);
   }
}