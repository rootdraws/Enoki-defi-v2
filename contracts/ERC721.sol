// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title ERC721UpgradeSafe
* @dev Upgradeable version of OpenZeppelin's ERC721 implementation
* Used for Mushroom NFTs to allow upgrades while preserving state/address
*/

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract ERC721UpgradeSafe is Initializable, ContextUpgradeSafe, ERC165UpgradeSafe, IERC721, IERC721Metadata, IERC721Enumerable {
   using SafeMath for uint256;
   using Address for address;
   using EnumerableSet for EnumerableSet.UintSet;
   using EnumerableMap for EnumerableMap.UintToAddressMap;
   using Strings for uint256;

   // Magic value for ERC721 receiver validation
   bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

   // Core storage mappings
   mapping (address => EnumerableSet.UintSet) private _holderTokens;        // Maps addresses to their owned tokens
   EnumerableMap.UintToAddressMap private _tokenOwners;                     // Maps token IDs to owners
   mapping (uint256 => address) private _tokenApprovals;                    // Maps token ID to approved address
   mapping (address => mapping (address => bool)) private _operatorApprovals;// Maps owner to operator approvals

   // Metadata storage
   string private _name;                        // Token collection name
   string private _symbol;                      // Token symbol
   mapping(uint256 => string) private _tokenURIs;// Individual token URIs
   string private _baseURI;                     // Base URI for all tokens

   // Interface IDs for ERC165 detection
   bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
   bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;
   bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

   /**
    * @dev Initializer function - replaces constructor for upgradeable pattern
    * @param name Name of the NFT collection
    * @param symbol Symbol for the NFT collection
    */
   function __ERC721_init(string memory name, string memory symbol) internal initializer {
       __Context_init_unchained();
       __ERC165_init_unchained();
       __ERC721_init_unchained(name, symbol);
   }

   function __ERC721_init_unchained(string memory name, string memory symbol) internal initializer {
       _name = name;
       _symbol = symbol;

       // Register ERC721 interfaces
       _registerInterface(_INTERFACE_ID_ERC721);
       _registerInterface(_INTERFACE_ID_ERC721_METADATA);
       _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
   }

   // Standard ERC721 functionality with upgradeable modifications...
   // [Previous function implementations remain the same]

   /**
    * @dev Storage gap for upgrade safety
    * Reserves storage slots to avoid layout collisions in future upgrades
    */
   uint256[41] private __gap;
}