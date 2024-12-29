// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./MushroomLib.sol";

// File Modernized by Claude.AI Sonnet on 12/29/24.

/**
 * @title MushroomNFT
 * @notice Specialized ERC721 implementation for Mushroom NFTs
 * @dev Extends NFT with mushroom traits and lifecycle management
 */
contract MushroomNFT is 
    ERC721Burnable, 
    Ownable, 
    AccessControl,
    ReentrancyGuard 
{
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    /// @notice Access control roles
    bytes32 public constant LIFESPAN_MODIFIER_ROLE = keccak256("LIFESPAN_MODIFIER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Core data storage
    mapping(uint256 => MushroomLib.MushroomData) private _mushroomData;
    mapping(uint256 => MushroomLib.MushroomType) private _mushroomTypes;
    mapping(uint256 => bool) private _mushroomTypeExists;
    mapping(uint256 => string) private _mushroomMetadataUri;

    /**
     * @notice Emitted when a new mushroom is minted
     * @param recipient Address receiving the mushroom
     * @param tokenId ID of the minted token
     * @param speciesId Species of the mushroom
     * @param lifespan Initial lifespan value
     */
    event MushroomMinted(
        address indexed recipient,
        uint256 indexed tokenId,
        uint256 indexed speciesId,
        uint256 lifespan
    );

    /**
     * @notice Emitted when a mushroom is burned
     * @param tokenId ID of the burned token
     * @param speciesId Species of the mushroom
     * @param burnedBy Address that burned the token
     */
    event MushroomBurned(
        uint256 indexed tokenId,
        uint256 indexed speciesId,
        address indexed burnedBy
    );

    /**
     * @notice Error thrown when token does not exist
     */
    error TokenNotFound(uint256 tokenId);

    /**
     * @notice Error thrown when species does not exist
     */
    error SpeciesNotFound(uint256 speciesId);

    /**
     * @notice Error thrown when species already exists
     */
    error SpeciesExists(uint256 speciesId);

    /**
     * @notice Error thrown when species cap is reached
     */
    error SpeciesCapReached(uint256 speciesId);

    /**
     * @notice Error thrown when recipient is invalid
     */
    error InvalidRecipient(address recipient);

    /**
     * @notice Error thrown when species data is invalid
     */
    error InvalidSpeciesData();

    constructor() 
        ERC721("Enoki Mushrooms", "ENOKI") 
        Ownable(msg.sender) 
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Gets mushroom data for a token
     * @param tokenId Token to query
     */
    function getMushroomData(
        uint256 tokenId
    ) external view returns (MushroomLib.MushroomData memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenNotFound(tokenId);
        return _mushroomData[tokenId];
    }

    /**
     * @notice Gets species configuration
     * @param speciesId Species to query
     */
    function getSpecies(
        uint256 speciesId
    ) external view returns (MushroomLib.MushroomType memory) {
        if (!_mushroomTypeExists[speciesId]) {
            revert SpeciesNotFound(speciesId);
        }
        return _mushroomTypes[speciesId];
    }

    /**
     * @notice Gets remaining mintable for species
     * @param speciesId Species to check
     * @return Remaining mintable amount
     */
    function getRemainingMintableForSpecies(
        uint256 speciesId
    ) external view returns (uint256) {
        if (!_mushroomTypeExists[speciesId]) {
            revert SpeciesNotFound(speciesId);
        }
        
        MushroomLib.MushroomType storage species = _mushroomTypes[speciesId];
        return species.cap > species.minted ? species.cap - species.minted : 0;
    }

    /**
     * @notice Mints a new mushroom
     * @param recipient Recipient address
     * @param tokenId Token ID to mint
     * @param speciesId Species of mushroom
     * @param lifespan Initial lifespan
     */
    function mint(
        address recipient,
        uint256 tokenId,
        uint256 speciesId,
        uint256 lifespan
    ) external nonReentrant onlyRole(MINTER_ROLE) {
        if (recipient == address(0)) revert InvalidRecipient(recipient);
        _mintWithMetadata(recipient, tokenId, speciesId, lifespan);
    }

    /**
     * @notice Burns a mushroom
     * @param tokenId Token to burn
     */
    function burn(
        uint256 tokenId
    ) public override nonReentrant {
        address owner = ownerOf(tokenId);
        super.burn(tokenId);
        _clearMushroomData(tokenId, owner);
    }

    /**
     * @dev Internal mint implementation
     */
    function _mintWithMetadata(
        address recipient,
        uint256 tokenId,
        uint256 speciesId,
        uint256 lifespan
    ) internal {
        if (!_mushroomTypeExists[speciesId]) {
            revert SpeciesNotFound(speciesId);
        }
        
        MushroomLib.MushroomType storage species = _mushroomTypes[speciesId];
        if (species.minted >= species.cap) {
            revert SpeciesCapReached(speciesId);
        }

        unchecked {
            species.minted++;
        }

        _mushroomData[tokenId] = MushroomLib.MushroomData({
            species: speciesId,
            strength: species.strength,
            lifespan: lifespan
        });

        _safeMint(recipient, tokenId);
        
        emit MushroomMinted(recipient, tokenId, speciesId, lifespan);
    }

    /**
     * @dev Cleans up mushroom data on burn
     */
    function _clearMushroomData(
        uint256 tokenId, 
        address burner
    ) internal {
        MushroomLib.MushroomData memory data = _mushroomData[tokenId];
        
        if (_mushroomTypeExists[data.species]) {
            unchecked {
                _mushroomTypes[data.species].minted--;
            }
        }

        delete _mushroomData[tokenId];
        
        emit MushroomBurned(tokenId, data.species, burner);
    }

    /**
     * @notice Adds a new mushroom species
     * @param speciesId Species identifier
     * @param speciesData Species configuration
     */
    function addMushroomType(
        uint256 speciesId,
        MushroomLib.MushroomType memory speciesData
    ) external onlyOwner {
        if (_mushroomTypeExists[speciesId]) {
            revert SpeciesExists(speciesId);
        }

        // Validate species data
        if (speciesData.id == 0 ||
            speciesData.strength == 0 ||
            speciesData.minLifespan == 0 ||
            speciesData.maxLifespan <= speciesData.minLifespan ||
            speciesData.cap == 0) {
            revert InvalidSpeciesData();
        }
        
        _mushroomTypes[speciesId] = speciesData;
        _mushroomTypeExists[speciesId] = true;
    }

    /**
     * @inheritdoc ERC721
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(
        ERC721,
        AccessControl
    ) returns (bool) {
        return 
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }
}