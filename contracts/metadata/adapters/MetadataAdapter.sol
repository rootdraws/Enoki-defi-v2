// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../MushroomLib.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MetadataAdapter
 * @dev Abstract contract that serves as an interface for reading and modifying mushroom NFT metadata
 * 
 * This contract has two main responsibilities:
 * 1. Reading metadata for mushroom NFTs from a given NFT contract
 * 2. Managing lifespan modifications through authorized roles
 * 
 * The contract uses OpenZeppelin's AccessControl for role-based permissions
 * and integrates with MushroomLib for data structure definitions
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

abstract contract MetadataAdapter is AccessControl {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    // Role identifier for addresses authorized to modify mushroom lifespans
    bytes32 public constant LIFESPAN_MODIFIER_ROLE = keccak256("LIFESPAN_MODIFIER_ROLE");

    /**
     * @dev Modifier that restricts function access to addresses with lifespan modification role
     */
    modifier onlyLifespanModifier() {
        _checkRole(LIFESPAN_MODIFIER_ROLE, msg.sender);
        _;
    }

    /**
     * @dev Retrieves mushroom metadata for a given token index
     * @param index The token ID to query
     * @param data Additional data required by the implementation
     * @return MushroomData struct containing the mushroom's metadata
     */
    function getMushroomData(uint256 index, bytes calldata data) external view virtual returns (MushroomLib.MushroomData memory);

    /**
     * @dev Updates the lifespan of a mushroom token
     * @param index The token ID to modify
     * @param lifespan The new lifespan value
     * @param data Additional data required by the implementation
     */

    // In the MetadataAdapter abstract contract
    function setMushroomLifespan(uint256 index, uint256 lifespan, bytes calldata data) external virtual;

        /*
        // In the inheriting contract
        function setMushroomLifespan(uint256 index, uint256 lifespan, bytes calldata data) external override onlyLifespanModifier {
            // Function implementation
        }
        */
    /**
     * @dev Checks if a mushroom token can be burned
     * @param index The token ID to query
     * @return bool indicating if the token can be burned
     */
    function isBurnable(uint256 index) external view virtual returns (bool);

    /**
     * @dev Checks if a mushroom token can be staked
     * @param index The token ID to query
     * @return bool indicating if the token can be staked
     */
    function isStakeable(uint256 index) external view virtual returns (bool);

    /**
     * @dev Emitted when the lifespan of a mushroom token is updated
     * @param index The token ID that was modified
     * @param lifespan The new lifespan value
     */
    event LifespanUpdated(uint256 indexed index, uint256 lifespan);
}