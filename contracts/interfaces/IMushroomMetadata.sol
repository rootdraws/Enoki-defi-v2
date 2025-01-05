// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../MushroomLib.sol";

// Now that the bottom contracts are all Modernized, we need to upgrade these Interfaces
// Copy the bottom contracts, and then say, Create an interface for these please, here is the previous interface.

/**
 * @title IMushroomMetadata
 * @notice Interface for managing mushroom NFT metadata and lifecycle
 * @dev Defines core functionality for mushroom metadata management
 */
interface IMushroomMetadata {
    /**
     * @notice Emitted when a mushroom's lifespan is updated
     * @param nftContract Address of the NFT contract
     * @param nftIndex Token ID of the mushroom
     * @param lifespan New lifespan value
     */
    event MushroomLifespanSet(
        address indexed nftContract,
        uint256 indexed nftIndex,
        uint256 lifespan
    );

    /**
     * @notice Emitted when a resolver is set for an NFT contract
     * @param nftContract Address of the NFT contract
     * @param resolver Address of the new resolver
     */
    event ResolverSet(
        address indexed nftContract,
        address indexed resolver
    );

    /**
     * @notice Error thrown when NFT contract address is invalid
     * @param nftContract The invalid contract address
     */
    error InvalidNFTContract(address nftContract);

    /**
     * @notice Error thrown when resolver address is invalid
     * @param resolver The invalid resolver address
     */
    error InvalidResolver(address resolver);

    /**
     * @notice Error thrown when lifespan value is invalid
     * @param lifespan The invalid lifespan value
     */
    error InvalidLifespan(uint256 lifespan);

    /**
     * @notice Checks if an NFT contract has a metadata adapter
     * @param nftContract Address of the NFT contract to check
     * @return bool True if the contract has a metadata adapter
     */
    function hasMetadataAdapter(
        address nftContract
    ) external view returns (bool);

    /**
     * @notice Retrieves mushroom data for a specific NFT
     * @param nftContract Address of the NFT contract
     * @param nftIndex Token ID of the mushroom
     * @param data Additional data for the metadata adapter
     * @return MushroomLib.MushroomData Mushroom metadata
     */
    function getMushroomData(
        address nftContract,
        uint256 nftIndex,
        bytes calldata data
    ) external view returns (MushroomLib.MushroomData memory);

    /**
     * @notice Updates the lifespan of a mushroom NFT
     * @param nftContract Address of the NFT contract
     * @param nftIndex Token ID of the mushroom
     * @param lifespan New lifespan value
     * @param data Additional data for the metadata adapter
     */
    function setMushroomLifespan(
        address nftContract,
        uint256 nftIndex,
        uint256 lifespan,
        bytes calldata data
    ) external;

    /**
     * @notice Sets the resolver for an NFT contract
     * @param nftContract Address of the NFT contract
     * @param resolver Address of the new resolver
     */
    function setResolver(
        address nftContract,
        address resolver
    ) external;
}

// Claude added an Abstracat Contract here.

/**
 * @title BaseMushroomMetadata
 * @notice Base implementation of the IMushroomMetadata interface
 * @dev Provides common functionality and library usage
 */
abstract contract BaseMushroomMetadata is IMushroomMetadata {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    /**
     * @dev Internal function to validate NFT contract address
     */
    function _validateNFTContract(address nftContract) internal pure {
        if (nftContract == address(0)) {
            revert InvalidNFTContract(nftContract);
        }
    }

    /**
     * @dev Internal function to validate resolver address
     */
    function _validateResolver(address resolver) internal pure {
        if (resolver == address(0)) {
            revert InvalidResolver(resolver);
        }
    }

    /**
     * @dev Internal function to validate lifespan value
     */
    function _validateLifespan(uint256 lifespan) internal pure {
        if (lifespan == 0) {
            revert InvalidLifespan(lifespan);
        }
    }
}