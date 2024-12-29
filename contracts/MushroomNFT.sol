// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./MushroomLib.sol";

/**
 * @title MushroomNFT
 * @notice Specialized ERC721 implementation for Mushroom NFTs
 * @dev Extends standard NFT with unique mushroom traits and controls
 * 
 * Key Features:
 * - Custom metadata tracking
 * - Species management system
 * - Role-based minting and lifespan modification
 * - Advanced burning mechanics
 */
contract MushroomNFT is ERC721Burnable, Ownable, AccessControl {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    // Role definitions
    bytes32 public constant LIFESPAN_MODIFIER_ROLE = keccak256("LIFESPAN_MODIFIER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Core storage mappings
    mapping(uint256 => MushroomLib.MushroomData) private _mushroomData;
    mapping(uint256 => MushroomLib.MushroomType) private _mushroomTypes;
    mapping(uint256 => bool) private _mushroomTypeExists;
    mapping(uint256 => string) private _mushroomMetadataUri;

    // Events
    event MushroomMinted(
        address indexed recipient, 
        uint256 indexed tokenId, 
        uint256 speciesId
    );
    event MushroomBurned(
        uint256 indexed tokenId, 
        uint256 speciesId
    );

    /**
     * @notice Constructor sets up the Mushroom NFT contract
     */
    constructor() 
        ERC721("Enoki Mushrooms", "ENOKI") 
        Ownable(msg.sender) 
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Retrieve mushroom metadata for a specific token
     * @param tokenId ID of the token to query
     * @return Mushroom data struct
     */
    function getMushroomData(uint256 tokenId) external view returns (MushroomLib.MushroomData memory) {
        require(_exists(tokenId), "Token does not exist");
        return _mushroomData[tokenId];
    }

    /**
     * @notice Retrieve species information
     * @param speciesId ID of the species to query
     * @return Mushroom species struct
     */
    function getSpecies(uint256 speciesId) external view returns (MushroomLib.MushroomType memory) {
        require(_mushroomTypeExists[speciesId], "Species does not exist");
        return _mushroomTypes[speciesId];
    }

    /**
     * @notice Check remaining mintable mushrooms for a species
     * @param speciesId Species to check
     * @return Number of mushrooms still available to mint
     */
    function getRemainingMintableForSpecies(uint256 speciesId) external view returns (uint256) {
        require(_mushroomTypeExists[speciesId], "Species does not exist");
        MushroomLib.MushroomType storage species = _mushroomTypes[speciesId];
        return species.cap > species.minted ? species.cap - species.minted : 0;
    }

    /**
     * @notice Mint a new mushroom
     * @param recipient Address to receive the mushroom
     * @param tokenId Unique token ID
     * @param speciesId Species of the mushroom
     * @param lifespan Lifespan of the mushroom
     */
    function mint(
        address recipient, 
        uint256 tokenId, 
        uint256 speciesId, 
        uint256 lifespan
    ) external onlyRole(MINTER_ROLE) {
        _mintWithMetadata(recipient, tokenId, speciesId, lifespan);
    }

    /**
     * @notice Burns a mushroom and updates species count
     * @param tokenId Token to burn
     */
    function burn(uint256 tokenId) public override {
        super.burn(tokenId);
        _clearMushroomData(tokenId);
    }

    /**
     * @notice Internal function to mint mushroom with metadata
     */
    function _mintWithMetadata(
        address recipient, 
        uint256 tokenId, 
        uint256 speciesId, 
        uint256 lifespan
    ) internal {
        require(_mushroomTypeExists[speciesId], "Invalid mushroom species");
        
        MushroomLib.MushroomType storage species = _mushroomTypes[speciesId];
        require(species.minted < species.cap, "Species minting cap reached");

        species.minted += 1;
        _mushroomData[tokenId] = MushroomLib.MushroomData({
            species: speciesId,
            strength: species.strength,
            lifespan: lifespan
        });

        _safeMint(recipient, tokenId);
        
        emit MushroomMinted(recipient, tokenId, speciesId);
    }

    /**
     * @notice Clear mushroom-specific data when token is burned
     * @param tokenId Token to clear data for
     */
    function _clearMushroomData(uint256 tokenId) internal {
        MushroomLib.MushroomData memory data = _mushroomData[tokenId];
        
        // Decrement minted count for the species
        if (_mushroomTypeExists[data.species]) {
            _mushroomTypes[data.species].minted -= 1;
        }

        // Clear the mushroom data
        delete _mushroomData[tokenId];
        
        emit MushroomBurned(tokenId, data.species);
    }

    /**
     * @notice Add a new mushroom species
     * @param speciesId Unique identifier for the species
     * @param speciesData Species configuration
     */
    function addMushroomType(
        uint256 speciesId, 
        MushroomLib.MushroomType memory speciesData
    ) external onlyOwner {
        require(!_mushroomTypeExists[speciesId], "Species already exists");
        
        _mushroomTypes[speciesId] = speciesData;
        _mushroomTypeExists[speciesId] = true;
    }

    /**
     * @dev Support for ERC165 and AccessControl interfaces
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC721, AccessControl) 
        returns (bool) 
    {
        return 
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }
}