// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
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
contract MetadataResolver is AccessControlUpgradeSafe {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    // Maps NFT contract addresses to their respective metadata adapter addresses
    mapping(address => address) public metadataAdapters;

    /**
     * @dev Restricts function access to admin role holders
     */
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "onlyAdmin");
        _;
    }

    /**
     * @dev Restricts function access to addresses with lifespan modification rights
     */
    modifier onlyLifespanModifier() {
        require(hasRole(LIFESPAN_MODIFY_REQUEST_ROLE, msg.sender), "onlyLifespanModifier");
        _;
    }

    // Role identifier for addresses authorized to modify mushroom lifespans
    bytes32 public constant LIFESPAN_MODIFY_REQUEST_ROLE = keccak256("LIFESPAN_MODIFY_REQUEST_ROLE");

    // Emitted when a new metadata adapter is set for an NFT contract
    event ResolverSet(address nft, address resolver);

    /**
     * @dev Ensures the NFT contract has a registered metadata adapter
     */
    modifier onlyWithMetadataAdapter(address nftContract) {
        require(metadataAdapters[nftContract] != address(0), "MetadataRegistry: No resolver set for nft");
        _;
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
        if (metadataAdapters[nftContract] == address(0)) {
            return false;
        }
        
        MetadataAdapter resolver = MetadataAdapter(metadataAdapters[nftContract]);
        return resolver.isStakeable(nftIndex);
    }

    /**
     * @dev Initializes the contract with an initial lifespan modifier
     * @param initialLifespanModifier_ Address to receive lifespan modification rights
     */
    function initialize(address initialLifespanModifier_) public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(LIFESPAN_MODIFY_REQUEST_ROLE, initialLifespanModifier_);
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
        MushroomLib.MushroomData memory mushroomData = resolver.getMushroomData(nftIndex, data);
        return mushroomData;
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
    ) external onlyWithMetadataAdapter(nftContract) onlyLifespanModifier {
        MetadataAdapter resolver = MetadataAdapter(metadataAdapters[nftContract]);
        resolver.setMushroomLifespan(nftIndex, lifespan, data);
    }

    /**
     * @dev Registers or updates a metadata adapter for an NFT contract
     * @param nftContract The NFT contract address
     * @param resolver The metadata adapter address
     */
    function setResolver(address nftContract, address resolver) public onlyAdmin {
        metadataAdapters[nftContract] = resolver;

        emit ResolverSet(nftContract, resolver);
    }
}