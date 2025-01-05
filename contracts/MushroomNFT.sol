// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC721UpgradeSafe.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";

import "./MushroomLib.sol";

// File Modernized by Claude.AI Sonnet on 1/4/25.

/**
 * @title MushroomNFT
 * @notice Upgradeable NFT implementation for Mushroom ecosystem
 * @dev Implements species-based NFTs with lifespan mechanics
 * @custom:security-contact security@example.com
 */

contract MushroomNFT is 
    ERC721UpgradeSafe,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable
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
    
    /// @dev Internal counter for token IDs
    uint256 private _nextTokenId;

    /// @dev Events
    event MushroomMinted(
        address indexed recipient,
        uint256 indexed tokenId,
        uint256 indexed speciesId,
        uint256 lifespan,
        uint256 timestamp
    );

    event MushroomBurned(
        uint256 indexed tokenId,
        uint256 indexed speciesId,
        address indexed burnedBy,
        uint256 timestamp
    );

    event SpeciesAdded(
        uint256 indexed speciesId,
        uint256 strength,
        uint256 cap,
        uint256 timestamp
    );

    /// @dev Custom errors
    error TokenNotFound(uint256 tokenId);
    error SpeciesNotFound(uint256 speciesId);
    error SpeciesExists(uint256 speciesId);
    error SpeciesCapReached(uint256 speciesId);
    error InvalidRecipient(address recipient);
    error InvalidSpeciesData();
    error CallerNotAuthorized();
    error TokenNotOwnedByCaller(uint256 tokenId, address caller);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the NFT contract
     * @param name Collection name
     * @param symbol Collection symbol
     * @param baseURI Base URI for token metadata
     */
    function initialize(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) external initializer {
        __ERC721UpgradeSafe_init(name, symbol, baseURI);
        __AccessControl_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(LIFESPAN_MODIFIER_ROLE, msg.sender);
        
        _nextTokenId = 1;
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
     * @notice Gets current token count
     * @return Current total supply
     */
    function totalSupply() public view override returns (uint256) {
        return _nextTokenId - 1;
    }

    /**
     * @notice Mints a new mushroom
     * @param recipient Recipient address
     * @param speciesId Species of mushroom
     * @param lifespan Initial lifespan
     * @return tokenId The ID of the newly minted token
     */
    function mint(
        address recipient,
        uint256 speciesId,
        uint256 lifespan
    ) external whenNotPaused nonReentrant onlyRole(MINTER_ROLE) returns (uint256 tokenId) {
        if (recipient == address(0)) revert InvalidRecipient(recipient);
        
        tokenId = _nextTokenId++;
        _mintWithMetadata(recipient, tokenId, speciesId, lifespan);
        return tokenId;
    }

    /**
     * @notice Burns a mushroom
     * @param tokenId Token to burn
     */
    function burn(
        uint256 tokenId
    ) public virtual override(ERC721BurnableUpgradeable) whenNotPaused nonReentrant {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) revert TokenNotFound(tokenId);
        
        if (_msgSender() != owner && !isApprovedForAll(owner, _msgSender()) && getApproved(tokenId) != _msgSender()) {
            revert TokenNotOwnedByCaller(tokenId, _msgSender());
        }
        
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
    ) internal virtual {
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
        
        emit MushroomMinted(
            recipient,
            tokenId,
            speciesId,
            lifespan,
            block.timestamp
        );
    }

    /**
     * @dev Cleans up mushroom data on burn
     */
    function _clearMushroomData(
        uint256 tokenId, 
        address burner
    ) internal virtual {
        MushroomLib.MushroomData memory data = _mushroomData[tokenId];
        
        if (_mushroomTypeExists[data.species]) {
            unchecked {
                _mushroomTypes[data.species].minted--;
            }
        }

        delete _mushroomData[tokenId];
        
        emit MushroomBurned(
            tokenId,
            data.species,
            burner,
            block.timestamp
        );
    }

    /**
     * @notice Adds a new mushroom species
     * @param speciesId Species identifier
     * @param speciesData Species configuration
     */
    function addMushroomType(
        uint256 speciesId,
        MushroomLib.MushroomType memory speciesData
    ) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
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

        emit SpeciesAdded(
            speciesId,
            speciesData.strength,
            speciesData.cap,
            block.timestamp
        );
    }

    /**
     * @dev Required overrides for multiple inheritance
     */
    function _increaseBalance(
        address account,
        uint128 amount
    ) internal virtual override(ERC721Upgradeable, ERC721UpgradeSafe) {
        super._increaseBalance(account, amount);
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override(ERC721Upgradeable, ERC721UpgradeSafe) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override(ERC721Upgradeable, ERC721UpgradeSafe) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721UpgradeSafe, ERC721Upgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}