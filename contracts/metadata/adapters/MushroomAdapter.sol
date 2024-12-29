// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../../MushroomNFT.sol";
import "../../MushroomLib.sol";
import "./MetadataAdapter.sol";

/**
 * @title MushroomAdapter
 * @dev Concrete implementation of MetadataAdapter for the MushroomNFT contract
 * 
 * This contract serves as a direct interface to the MushroomNFT contract,
 * handling metadata reading and lifespan modifications. It implements a fixed
 * forwarding mechanism that cannot be modified after initialization.
 *
 * Key features:
 * - Direct integration with MushroomNFT contract
 * - Fixed permission structure set at initialization
 * - All mushrooms are stakeable and burnable by default
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

contract MushroomAdapter is Initializable, MetadataAdapter {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    // Reference to the main MushroomNFT contract
    MushroomNFT public mushroomNft;

    /**
     * @dev Initializes the contract with NFT contract address and authorized forwarder
     * @param nftContract_ Address of the MushroomNFT contract
     * @param forwardActionsFrom_ Address authorized to modify lifespans
     */
    function initialize(address nftContract_, address forwardActionsFrom_) public initializer {
        mushroomNft = MushroomNFT(nftContract_);
        _setupRole(LIFESPAN_MODIFIER_ROLE, forwardActionsFrom_);
    }

    /**
     * @dev Retrieves mushroom metadata from the MushroomNFT contract
     * @param index The token ID to query
     * @param data Unused in this implementation but required by interface
     * @return MushroomData struct containing the mushroom's metadata
     */
    function getMushroomData(uint256 index, bytes calldata data) external view override returns (MushroomLib.MushroomData memory) {
        return mushroomNft.getMushroomData(index);
    }

    /**
     * @dev Always returns true as all mushrooms are stakeable in this implementation
     * @param nftIndex Unused but required by interface
     * @return bool Always returns true
     */
    function isStakeable(uint256 nftIndex) external pure override returns (bool) {
        return true;
    }

    /**
     * @dev Always returns true as all mushrooms are burnable in this implementation
     * @param index Unused but required by interface
     * @return bool Always returns true
     */
    function isBurnable(uint256 index) external pure override returns (bool) {
        return true;
    }

    /**
     * @dev Forwards lifespan modification requests to the MushroomNFT contract
     * @param index The token ID to modify
     * @param lifespan The new lifespan value
     * @param data Unused in this implementation but required by interface
     */
    function setMushroomLifespan(uint256 index, uint256 lifespan, bytes calldata data) external onlyLifespanModifier {
        mushroomNft.setMushroomLifespan(index, lifespan);
        emit LifespanUpdated(index, lifespan);
    }
}