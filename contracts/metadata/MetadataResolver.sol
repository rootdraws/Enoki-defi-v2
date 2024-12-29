// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./adapters/MetadataAdapter.sol";
import "../MushroomLib.sol";

/**
 * @title MetadataResolver
 * @dev Central hub contract that manages metadata adapters for different NFT contracts
 * 
 * This contract serves as a registry and coordinator for multiple NFT metadata adapters.
 * Each NFT contract can have its own custom adapter implementation to handle
 * metadata operations in a way specific to that NFT's requirements.
 *
 * Key features:
 * - Registry of metadata adapters for different NFT contracts
 * - Role-based access control for admin and lifespan modification
 * - Standardized interface for metadata operations across different NFT types
 */

/**
 * @dev The metadata-focused contracts work together to provide a flexible and modular system
 * for managing and accessing metadata for different types of NFTs (Non-Fungible Tokens).
 *
 * The main contracts involved are:
 *
 * 1. MetadataResolver:
 *    - Acts as a central hub and registry for metadata adapters.
 *    - Maps NFT contract addresses to their respective metadata adapter addresses.
 *    - Provides a standardized interface for accessing metadata across different NFT types.
 *    - Allows setting and updating metadata adapters for NFT contracts.
 *    - Implements role-based access control for admin and lifespan modification permissions.
 *
 * 2. MetadataAdapter (abstract):
 *    - Defines an abstract contract that serves as the interface for reading and modifying NFT metadata.
 *    - Contains functions for retrieving mushroom data, checking if an NFT is stakeable and burnable,
 *      and updating the lifespan of an NFT.
 *    - Implements role-based access control for lifespan modification permissions.
 *    - Emits events for lifespan updates.
 *
 * 3. MushroomAdapter (concrete):
 *    - A concrete implementation of the MetadataAdapter abstract contract.
 *    - Provides metadata adaptation specifically for the MushroomNFT contract.
 *    - Interacts directly with the MushroomNFT contract to retrieve and modify mushroom metadata.
 *    - Implements the functions defined in the MetadataAdapter abstract contract.
 *
 * The flow of metadata retrieval and modification works as follows:
 *
 * 1. The MetadataResolver contract acts as the entry point for accessing metadata.
 * 2. When a request for metadata is made, the MetadataResolver checks if a metadata adapter
 *    is registered for the corresponding NFT contract.
 * 3. If a metadata adapter is found, the MetadataResolver delegates the metadata request to
 *    the appropriate adapter contract (e.g., MushroomAdapter for MushroomNFT).
 * 4. The metadata adapter contract interacts with the specific NFT contract (e.g., MushroomNFT)
 *    to retrieve or modify the metadata based on the requested operation.
 * 5. The metadata is returned to the caller via the MetadataResolver contract.
 *
 * This modular architecture allows for flexibility and extensibility, as new metadata adapters
 * can be easily integrated for different NFT contracts without modifying the core MetadataResolver
 * contract. The use of abstract contracts and interfaces ensures a consistent and standardized
 * approach to metadata management across various NFT types.
 */

contract MetadataResolver is Initializable, AccessControl {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    // Maps NFT contract addresses to their respective metadata adapter addresses
    mapping(address => address) public metadataAdapters;

    // Role identifier for addresses authorized to modify mushroom lifespans
    bytes32 public constant LIFESPAN_MODIFIER_ROLE = keccak256("LIFESPAN_MODIFIER_ROLE");

    // Emitted when a new metadata adapter is set for an NFT contract.
    event ResolverSet(address indexed nftContract, address resolver);
    
    // Emitted when Lifespan is updated.
    event LifespanUpdated(address indexed nftContract, uint256 indexed nftIndex, uint256 lifespan);

    /**
     * @dev Ensures the NFT contract has a registered metadata adapter
     */
    modifier onlyWithMetadataAdapter(address nftContract) {
        require(metadataAdapters[nftContract] != address(0), "MetadataRegistry: No resolver set for NFT");
        _;
    }

    /**
     * @dev Initializes the contract with an initial lifespan modifier
     * @param initialLifespanModifier Address to receive lifespan modification rights
     */
    function initialize(address initialLifespanModifier) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIFESPAN_MODIFIER_ROLE, initialLifespanModifier);
    }

    /**
     * @dev Checks if an NFT contract has a registered metadata adapter
     * @param nftContract The NFT contract address to check
     * @return bool indicating if adapter exists
     */
    function hasMetadataAdapter(address nftContract) external view returns (bool) {
        return metadataAdapters[nftContract] != address(0);
    }

    /**
     * @dev Returns the metadata adapter address for an NFT contract
     * @param nftContract The NFT contract address
     * @return address of the metadata adapter
     */
    function getMetadataAdapter(address nftContract) external view returns (address) {
        return metadataAdapters[nftContract];
    }

    /**
     * @dev Checks if a specific NFT token can be staked
     * @param nftContract The NFT contract address
     * @param nftIndex The token ID to check
     * @return bool indicating if token can be staked
     */
    function isStakeable(address nftContract, uint256 nftIndex) external view returns (bool) {
        MetadataAdapter resolver = MetadataAdapter(metadataAdapters[nftContract]);
        return resolver.isStakeable(nftIndex);
    }

    /**
     * @dev Retrieves mushroom metadata for a specific NFT token
     * @param nftContract The NFT contract address
     * @param nftIndex The token ID
     * @param data Additional data required by the adapter
     * @return MushroomData struct containing the mushroom's metadata
     */
    function getMushroomData(
        address nftContract,
        uint256 nftIndex,
        bytes calldata data
    ) external view onlyWithMetadataAdapter(nftContract) returns (MushroomLib.MushroomData memory) {
        MetadataAdapter resolver = MetadataAdapter(metadataAdapters[nftContract]);
        return resolver.getMushroomData(nftIndex, data);
    }

    /**
     * @dev Checks if a specific NFT token can be burned
     * @param nftContract The NFT contract address
     * @param nftIndex The token ID
     * @return bool indicating if token can be burned
     */
    function isBurnable(address nftContract, uint256 nftIndex) external view onlyWithMetadataAdapter(nftContract) returns (bool) {
        MetadataAdapter resolver = MetadataAdapter(metadataAdapters[nftContract]);
        return resolver.isBurnable(nftIndex);
    }

    /**
     * @dev Updates the lifespan of a specific NFT token
     * @param nftContract The NFT contract address
     * @param nftIndex The token ID
     * @param lifespan The new lifespan value
     * @param data Additional data required by the adapter
     */
    function setMushroomLifespan(
        address nftContract,
        uint256 nftIndex,
        uint256 lifespan,
        bytes calldata data
    ) external onlyWithMetadataAdapter(nftContract) onlyRole(LIFESPAN_MODIFIER_ROLE) {
        MetadataAdapter resolver = MetadataAdapter(metadataAdapters[nftContract]);
        resolver.setMushroomLifespan(nftIndex, lifespan, data);
        
        emit LifespanUpdated(nftContract, nftIndex, lifespan);
    }

    /**
     * @dev Registers or updates a metadata adapter for an NFT contract
     * @param nftContract The NFT contract address
     * @param resolver The metadata adapter address
     */
    function setResolver(address nftContract, address resolver) public onlyRole(DEFAULT_ADMIN_ROLE) {
        metadataAdapters[nftContract] = resolver;
        emit ResolverSet(nftContract, resolver);
    }
}