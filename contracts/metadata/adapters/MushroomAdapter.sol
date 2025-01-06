// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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
 
 This is a metadata adapter specifically designed for MushroomNFT contracts:

Key Features:
- Read-only metadata resolution
- Factory-controlled lifespan management
- Lightweight metadata interface

Core Functionality:
1. Metadata Operations
- Retrieve mushroom metadata
- Check token stakeable/burnable status
- Fetch species details
- Validate contract health

2. Security Mechanisms
- Reentrancy protection
- Initialization checks
- Immutable NFT contract reference

Unique Design Elements:
- Prevents lifespan modifications after minting
- Provides a standardized metadata interface
- Supports version tracking
- Maintains compatibility with metadata resolver

The contract acts as a read-only adapter that bridges the MushroomNFT contract with the ecosystem's metadata resolution system, ensuring consistent and controlled metadata access.
 
 */

contract MushroomAdapter is 
    Initializable, 
    ReentrancyGuardUpgradeable,
    BaseMetadataAdapter 
{
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    /// @dev Reference to the main MushroomNFT contract
    MushroomNFT public immutable mushroomNft;

    /// @dev Events for adapter operations

    /**
     * @dev Custom errors
     */
    error InvalidNFTContract(address nftContract);
    error InvalidForwarder(address forwarder);
    error TokenNotFound(uint256 tokenId);

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
     * @notice Checks if the contract is healthy
     * @inheritdoc IMetadataAdapter
     */
    function isHealthy() external view override returns (bool) {
        return address(mushroomNft) != address(0);
    }

    /**
     * @notice Get the species details for a token
     * @param tokenId Token to query
     * @return Species configuration
     * @inheritdoc IMetadataAdapter
     */
    function getSpeciesForToken(
        uint256 tokenId
    ) external view override returns (MushroomLib.MushroomType memory) {
        MushroomLib.MushroomData memory data = mushroomNft.getMushroomData(tokenId);
        return mushroomNft.getSpecies(data.species);
    }

    /**
     * @notice Returns current adapter version
     * @inheritdoc BaseMetadataAdapter
     */
    function version() public pure override returns (uint256) {
        return 2; // Incremented to reflect factory pattern
    }

    /**
     * @notice Returns explanation of lifespan modification policy
     * @inheritdoc BaseMetadataAdapter
     */
    function getLifespanModificationStatus() public pure override returns (string memory) {
        return "Lifespans are controlled by Factory at mint time and cannot be modified";
    }
}