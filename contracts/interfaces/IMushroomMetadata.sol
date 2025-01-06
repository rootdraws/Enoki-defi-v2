// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../MushroomLib.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title IMushroomMetadata
 * @notice Central hub interface for managing mushroom NFT metadata resolution
 * @dev Coordinates metadata operations across different NFT types through adapters
 */

interface IMushroomMetadata is IAccessControl {
    /**
     * @notice Emitted when a new metadata adapter is set
     * @param nftContract Address of the NFT contract
     * @param resolver Address of the metadata adapter
     * @param setBy Address that set the resolver
     */
    event ResolverSet(
        address indexed nftContract,
        address indexed resolver,
        address indexed setBy
    );

    /**
     * @notice Error thrown when NFT contract has no adapter
     */
    error NoMetadataAdapter(address nftContract);

    /**
     * @notice Error thrown when input address is invalid
     */
    error InvalidAddress(address addr);

    /**
     * @notice Error thrown when adapter operation fails
     */
    error AdapterOperationFailed(address adapter, string reason);

    /**
     * @notice Checks if an NFT contract has a registered adapter
     * @param nftContract The NFT contract to check
     * @return bool True if the contract has a registered adapter
     */
    function hasMetadataAdapter(
        address nftContract
    ) external view returns (bool);

    /**
     * @notice Gets the adapter address for an NFT contract
     * @param nftContract The NFT contract
     * @return Address of the metadata adapter
     */
    function getMetadataAdapter(
        address nftContract
    ) external view returns (address);

    /**
     * @notice Checks if a token can be staked
     * @param nftContract The NFT contract
     * @param nftIndex The token ID
     * @return True if token can be staked
     */
    function isStakeable(
        address nftContract,
        uint256 nftIndex
    ) external view returns (bool);

    /**
     * @notice Gets mushroom metadata for a token
     * @param nftContract The NFT contract
     * @param nftIndex The token ID
     * @param data Additional adapter data
     * @return Mushroom metadata structure
     */
    function getMushroomData(
        address nftContract,
        uint256 nftIndex,
        bytes calldata data
    ) external view returns (MushroomLib.MushroomData memory);

    /**
     * @notice Checks if a token can be burned
     * @param nftContract The NFT contract
     * @param nftIndex The token ID
     * @return True if token can be burned
     */
    function isBurnable(
        address nftContract,
        uint256 nftIndex
    ) external view returns (bool);

    /**
     * @notice Sets or updates an NFT's metadata adapter
     * @param nftContract The NFT contract
     * @param resolver The adapter address
     */
    function setResolver(
        address nftContract,
        address resolver
    ) external;
}