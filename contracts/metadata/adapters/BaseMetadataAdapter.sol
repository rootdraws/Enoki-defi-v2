// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IMetadataAdapter.sol";
import "../../MushroomLib.sol";

// Need to correct this, because the Lifepsan was structured differently.
// Lifespan is now handled by the MushroomFactory.sol

abstract contract BaseMetadataAdapter is IMetadataAdapter, AccessControl {
   using MushroomLib for MushroomLib.MushroomData;
   using MushroomLib for MushroomLib.MushroomType;

   bytes32 public constant LIFESPAN_MODIFIER_ROLE = keccak256("LIFESPAN_MODIFIER_ROLE");

   /**
    * @dev Modifier that validates token index
    */
   modifier validTokenIndex(uint256 index) {
       if (index == 0) revert InvalidTokenIndex(index);
       _;
   }

   /**
    * @dev Modifier that validates lifespan value
    */
   modifier validLifespan(uint256 lifespan) {
       if (lifespan == 0) revert InvalidLifespan(lifespan);
       _;
   }

   /**
    * @dev Modifier that restricts access to lifespan modifiers
    */
   modifier onlyLifespanModifier() {
       _checkRole(LIFESPAN_MODIFIER_ROLE, msg.sender);
       _;
   }

   /**
    * @notice Base implementation of lifespan update
    * @dev Must be extended by concrete implementations
    */
   function setMushroomLifespan(
       uint256 index,
       uint256 lifespan,
       bytes calldata data
   ) external virtual override 
     onlyLifespanModifier 
     validTokenIndex(index)
     validLifespan(lifespan) 
   {
       _setMushroomLifespan(index, lifespan, data);
       emit LifespanUpdated(index, lifespan, msg.sender);
   }

   /**
    * @dev Internal function to be implemented by concrete contracts
    */
   function _setMushroomLifespan(
       uint256 index,
       uint256 lifespan,
       bytes calldata data
   ) internal virtual;

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
}