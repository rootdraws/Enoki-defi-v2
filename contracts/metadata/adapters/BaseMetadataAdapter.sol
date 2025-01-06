// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IMetadataAdapter.sol";
import "../../MushroomLib.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title BaseMetadataAdapter
 * @notice Abstract base contract for mushroom metadata adapters
 * @dev Implements common functionality for metadata adapters
 
This is an abstract base contract providing a standardized foundation for mushroom metadata adapters:

Key Features:
- Implements common metadata adapter functionality
- Provides interface compatibility
- Defines core metadata resolution methods

Core Functionality:
1. Metadata Resolution
- Defines abstract methods for metadata retrieval
- Validates token index
- Supports version tracking
- Handles lifespan modification policy

2. Security Mechanisms
- Access control integration
- Interface validation
- Token index validation
- Error handling helpers

Unique Design Elements:
- Serves as a template for specific metadata adapters
- Removes direct lifespan modification
- Supports factory-controlled metadata
- Flexible interface extension
- Implements OpenZeppelin's AccessControl

The contract provides a robust, extensible base for creating metadata adapters with consistent behavior across different NFT implementations.
 
 */

abstract contract BaseMetadataAdapter is IMetadataAdapter, AccessControl {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    // Maintained for interface compatibility but no longer used for lifespan modification
    bytes32 public constant LIFESPAN_MODIFIER_ROLE = keccak256("LIFESPAN_MODIFIER_ROLE");

    /**
     * @dev Modifier that validates token index
     */
    modifier validTokenIndex(uint256 index) {
        if (index == 0) revert InvalidTokenIndex(index);
        _;
    }

    /**
     * @dev Internal helper to validate metadata operation success
     */
    function _requireValidOperation(
        bool success,
        uint256 index,
        string memory reason
    ) internal pure {
        if (!success) {
            revert MetadataOperationFailed(index, reason);
        }
    }

    /**
     * @notice Returns current adapter version
     */
    function version() public pure virtual returns (uint256) {
        return 2; // Incremented to reflect factory-controlled lifespan
    }

    /**
     * @notice Returns explanation of lifespan modification policy
     */
    function getLifespanModificationStatus() public pure virtual returns (string memory) {
        return "Lifespans are controlled by Factory at mint time and cannot be modified";
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl) returns (bool) {
        return
            interfaceId == type(IMetadataAdapter).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Required implementations by concrete contracts
     */
    function getMushroomData(
        uint256 index,
        bytes calldata data
    ) external view virtual returns (MushroomLib.MushroomData memory);

    function isBurnable(
        uint256 index
    ) external view virtual returns (bool);

    function isStakeable(
        uint256 index
    ) external view virtual returns (bool);

    function isHealthy() external view virtual returns (bool);

    function getSpeciesForToken(
        uint256 tokenId
    ) external view virtual returns (MushroomLib.MushroomType memory);
}