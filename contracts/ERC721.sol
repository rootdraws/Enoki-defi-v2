// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title ERC721UpgradeSafe
 * @notice Upgradeable ERC721 implementation with enumeration and URI storage
 */
abstract contract ERC721UpgradeSafe is 
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable 
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the upgradeable NFT contract
     * @param name Collection name
     * @param symbol Collection symbol
     */
    function __ERC721UpgradeSafe_init(
        string memory name,
        string memory symbol
    ) internal onlyInitializing {
        __ERC721_init(name, symbol);
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
    }

    /**
     * @dev Required override for ownership balance updates
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    /**
     * @notice Gets token URI
     * @param tokenId Token to query
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override(
        ERC721Upgradeable,
        ERC721URIStorageUpgradeable
    ) returns (string memory) {
        return ERC721URIStorageUpgradeable.tokenURI(tokenId);
    }

    /**
     * @notice Interface support check
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(
        ERC721Upgradeable,
        ERC721EnumerableUpgradeable,
        ERC721URIStorageUpgradeable
    ) returns (bool) {
        return 
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            ERC721EnumerableUpgradeable.supportsInterface(interfaceId) ||
            ERC721URIStorageUpgradeable.supportsInterface(interfaceId);
    }
}