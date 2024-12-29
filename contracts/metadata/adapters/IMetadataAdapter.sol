// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../MushroomLib.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

// File Modernized by Claude.AI Sonnet on 12/29/24.

interface IMetadataAdapter is IAccessControl {
   /**
    * @notice Emitted when a mushroom's lifespan is updated
    * @param index Token ID of the modified mushroom
    * @param lifespan New lifespan value
    * @param updatedBy Address that performed the modification
    */
   event LifespanUpdated(
       uint256 indexed index,
       uint256 indexed lifespan,
       address indexed updatedBy
   );

   /**
    * @notice Error thrown when token index is invalid
    * @param index The invalid token ID
    */
   error InvalidTokenIndex(uint256 index);

   /**
    * @notice Error thrown when lifespan value is invalid
    * @param lifespan The invalid lifespan value
    */
   error InvalidLifespan(uint256 lifespan);

   /**
    * @notice Error thrown when metadata operation fails
    * @param index Token ID of the mushroom
    * @param reason Failure reason
    */
   error MetadataOperationFailed(uint256 index, string reason);

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
    * @notice Updates the lifespan of a mushroom token
    * @param index Token ID to modify
    * @param lifespan New lifespan value
    * @param data Additional data required by implementation
    */
   function setMushroomLifespan(
       uint256 index,
       uint256 lifespan,
       bytes calldata data
   ) external;

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
}