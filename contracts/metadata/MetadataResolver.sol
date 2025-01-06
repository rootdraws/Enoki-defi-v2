// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./adapters/IMetadataAdapter.sol";
import "../MushroomLib.sol";

// Still has Errors related to Lifespan.

/**
 * @title MetadataResolver
 * @notice Central hub contract that manages metadata adapters for NFT contracts
 * @dev Coordinates metadata operations across different NFT types

This is a centralized metadata management contract for NFT ecosystems:

Key Features:
- Manages metadata adapters for different NFT contracts
- Acts as a routing hub for metadata operations
- Supports dynamic metadata resolution

Core Functionality:
1. Metadata Routing
- Maps NFT contracts to specific metadata adapters
- Provides methods to query NFT metadata
- Supports stakeable, burnable, and lifespan checks

2. Access Control
- Admin-controlled adapter registration
- Role-based lifespan modification
- Reentrancy protection

3. Metadata Operations
- Retrieve mushroom-specific data
- Update token lifespans
- Validate token attributes

Unique Design Elements:
- Flexible adapter architecture
- Centralized metadata resolution
- Comprehensive error handling
- Upgradeable contract design
- Supports multiple NFT contract types

The contract provides a flexible, secure mechanism for managing metadata across different NFT contracts in a complex ecosystem, acting as a universal metadata router.

 */

contract MetadataResolver is 
    AccessControlUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    /// @notice Maps NFT contracts to their metadata adapters
    mapping(address => address) public metadataAdapters;

    /// @notice Role for addresses authorized to modify lifespans
    bytes32 public constant LIFESPAN_MODIFIER_ROLE = keccak256("LIFESPAN_MODIFIER_ROLE");

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
     * @notice Emitted when a mushroom's lifespan is updated
     * @param nftContract Address of the NFT contract
     * @param nftIndex Token ID of the mushroom
     * @param lifespan New lifespan value
     * @param updatedBy Address that performed the update
     */
    event LifespanUpdated(
        address indexed nftContract,
        uint256 indexed nftIndex,
        uint256 lifespan,
        address indexed updatedBy
    );

    /**
     * @notice Thrown when NFT contract has no adapter
     */
    error NoMetadataAdapter(address nftContract);

    /**
     * @notice Thrown when input address is invalid
     */
    error InvalidAddress(address addr);

    /**
     * @notice Thrown when adapter operation fails
     */
    error AdapterOperationFailed(address adapter, string reason);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract
     * @param initialLifespanModifier Address to receive lifespan rights
     */
    function initialize(
        address initialLifespanModifier
    ) external initializer {
        if (initialLifespanModifier == address(0)) {
            revert InvalidAddress(initialLifespanModifier);
        }

        __AccessControl_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIFESPAN_MODIFIER_ROLE, initialLifespanModifier);
    }

    /**
     * @notice Checks if an NFT contract has a registered adapter
     * @param nftContract The NFT contract to check
     */
    function hasMetadataAdapter(
        address nftContract
    ) external view returns (bool) {
        return metadataAdapters[nftContract] != address(0);
    }

    /**
     * @notice Gets the adapter address for an NFT contract
     * @param nftContract The NFT contract
     */
    function getMetadataAdapter(
        address nftContract
    ) external view returns (address) {
        return metadataAdapters[nftContract];
    }

    /**
     * @notice Checks if a token can be staked
     * @param nftContract The NFT contract
     * @param nftIndex The token ID
     */
    function isStakeable(
        address nftContract,
        uint256 nftIndex
    ) external view returns (bool) {
        address adapter = metadataAdapters[nftContract];
        if (adapter == address(0)) revert NoMetadataAdapter(nftContract);
        
        return IMetadataAdapter(adapter).isStakeable(nftIndex);
    }

    /**
     * @notice Gets mushroom metadata for a token
     * @param nftContract The NFT contract
     * @param nftIndex The token ID
     * @param data Additional adapter data
     */
    function getMushroomData(
        address nftContract,
        uint256 nftIndex,
        bytes calldata data
    ) external view returns (MushroomLib.MushroomData memory) {
        address adapter = metadataAdapters[nftContract];
        if (adapter == address(0)) revert NoMetadataAdapter(nftContract);

        try IMetadataAdapter(adapter).getMushroomData(nftIndex, data) returns (
            MushroomLib.MushroomData memory mushroomData
        ) {
            return mushroomData;
        } catch Error(string memory reason) {
            revert AdapterOperationFailed(adapter, reason);
        }
    }

    /**
     * @notice Checks if a token can be burned
     * @param nftContract The NFT contract
     * @param nftIndex The token ID
     */
    function isBurnable(
        address nftContract,
        uint256 nftIndex
    ) external view returns (bool) {
        address adapter = metadataAdapters[nftContract];
        if (adapter == address(0)) revert NoMetadataAdapter(nftContract);
        
        return IMetadataAdapter(adapter).isBurnable(nftIndex);
    }

    /**
     * @notice Updates a token's lifespan
     * @param nftContract The NFT contract
     * @param nftIndex The token ID
     * @param lifespan The new lifespan
     * @param data Additional adapter data
     */
    function setMushroomLifespan(
        address nftContract,
        uint256 nftIndex,
        uint256 lifespan,
        bytes calldata data
    ) external nonReentrant onlyRole(LIFESPAN_MODIFIER_ROLE) {
        address adapter = metadataAdapters[nftContract];
        if (adapter == address(0)) revert NoMetadataAdapter(nftContract);

        try IMetadataAdapter(adapter).setMushroomLifespan(nftIndex, lifespan, data) {
            emit LifespanUpdated(nftContract, nftIndex, lifespan, msg.sender);
        } catch Error(string memory reason) {
            revert AdapterOperationFailed(adapter, reason);
        }
    }

    /**
     * @notice Sets or updates an NFT's metadata adapter
     * @param nftContract The NFT contract
     * @param resolver The adapter address
     */
    function setResolver(
        address nftContract,
        address resolver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (nftContract == address(0)) revert InvalidAddress(nftContract);
        if (resolver == address(0)) revert InvalidAddress(resolver);

        metadataAdapters[nftContract] = resolver;
        emit ResolverSet(nftContract, resolver, msg.sender);
    }
}