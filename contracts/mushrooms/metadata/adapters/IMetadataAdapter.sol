// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../MushroomLib.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title IMetadataAdapter
 * @notice Interface for mushroom metadata resolution with factory-controlled lifespans
 * @dev Removes lifespan modification as it's now controlled by factory at mint time
 
 This is an interface defining a standardized metadata resolution mechanism for mushroom-based NFTs:

Key Features:
- Defines metadata retrieval methods
- Supports token-level operations
- Factory-controlled lifespan management

Core Methods:
1. Metadata Queries
- Retrieve mushroom data
- Check token burnability and stakeable status
- Fetch token species details

2. Adapter Management
- Version tracking
- Contract health verification
- Lifespan modification status

Unique Design Elements:
- Extends access control interface
- Removes direct lifespan modification
- Provides flexible metadata resolution
- Supports additional data pass-through
- Includes custom error handling

The interface establishes a consistent, extensible contract for resolving and managing NFT metadata across different implementations, with a focus on mushroom-specific attributes.
 
 */

interface IMetadataAdapter is IAccessControl {
    /**
     * @notice Emitted when an unsupported lifespan operation is attempted
     * @param reason Explanation of factory control
     */
    event UnsupportedOperation(string reason);
    /**
     * @notice Error thrown when token index is invalid
     * @param index The invalid token ID
     */
    error InvalidTokenIndex(uint256 index);

    /**
     * @notice Error thrown when metadata operation fails
     * @param index Token ID of the mushroom
     * @param reason Failure reason
     */
    error MetadataOperationFailed(uint256 index, string reason);

    /**
     * @notice Error thrown when lifespan modification is attempted
     */
    error LifespanModificationNotSupported();

    /**
     * @notice Retrieves mushroom metadata for a given token
     * @param index Token ID to query
     * @param data Additional data required by implementation
     * @return Mushroom metadata structure
     */
    function getMushroomData(
        uint256 index,
        bytes calldata data
    ) external view returns (MushroomLib.MushroomData memory);

    /**
     * @notice Checks if a mushroom token can be burned
     * @param index Token ID to query
     * @return Whether the token can be burned
     */
    function isBurnable(uint256 index) external view returns (bool);

    /**
     * @notice Checks if a mushroom token can be staked
     * @param index Token ID to query
     * @return Whether the token can be staked
     */
    function isStakeable(uint256 index) external view returns (bool);

    /**
     * @notice Returns the version of the metadata adapter
     * @return Current version number
     */
    function version() external pure returns (uint256);

    /**
     * @notice Checks if the adapter is properly connected to NFT contract
     * @return Whether the adapter is healthy
     */
    function isHealthy() external view returns (bool);

    /**
     * @notice Gets species information for a token
     * @param tokenId Token to query
     * @return Species configuration
     */
    function getSpeciesForToken(
        uint256 tokenId
    ) external view returns (MushroomLib.MushroomType memory);

    /**
     * @notice Explains the current lifespan modification policy
     * @return Message explaining factory control
     */
    function getLifespanModificationStatus() external pure returns (string memory);
}