// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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
abstract contract MetadataAdapter is AccessControlUpgradeSafe {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    // Role identifier for addresses authorized to modify mushroom lifespans
    bytes32 public constant LIFESPAN_MODIFY_REQUEST_ROLE = keccak256("LIFESPAN_MODIFY_REQUEST_ROLE");

    /**
     * @dev Modifier that restricts function access to addresses with lifespan modification role
     */
    modifier onlyLifespanModifier() {
        require(hasRole(LIFESPAN_MODIFY_REQUEST_ROLE, msg.sender), "onlyLifespanModifier");
        _;
    }

    /**
     * @dev Retrieves mushroom metadata for a given token index
     * @param index The token ID to query
     * @param data Additional data required by the implementation
     * @return MushroomData struct containing the mushroom's metadata
     */
    function getMushroomData(uint256 index, bytes calldata data) external virtual view returns (MushroomLib.MushroomData memory);

    /**
     * @dev Updates the lifespan of a mushroom token
     * @param index The token ID to modify
     * @param lifespan The new lifespan value
     * @param data Additional data required by the implementation
     */
    function setMushroomLifespan(uint256 index, uint256 lifespan, bytes calldata data) external virtual;

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
}