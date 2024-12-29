// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ERC721UpgradeSafe
 * @notice Upgradeable ERC721 implementation for Mushroom NFTs
 * @dev Allows contract upgrades while preserving state and address
 */
abstract contract ERC721UpgradeSafe is 
    Initializable, 
    ERC721Upgradeable, 
    ERC721EnumerableUpgradeable, 
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable 
{
    /**
     * @dev Initializer function for the upgradeable NFT contract
     * @param name Name of the NFT collection
     * @param symbol Symbol for the NFT collection
     */
    function __ERC721UpgradeSafe_init(
        string memory name, 
        string memory symbol
    ) internal onlyInitializing {
        __Initializable_init();
        __ERC721_init(name, symbol);
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __Ownable_init(msg.sender);
    }

    /**
     * @dev Override required by multiple inheritance
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    /**
     * @dev Override tokenURI to use URIStorage implementation
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return ERC721URIStorageUpgradeable.tokenURI(tokenId);
    }

    /**
     * @dev Override supportsInterface to resolve multiple inheritance
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC721Upgradeable, 
            ERC721EnumerableUpgradeable, 
            ERC721URIStorageUpgradeable
        )
        returns (bool)
    {
        return 
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            ERC721EnumerableUpgradeable.supportsInterface(interfaceId) ||
            ERC721URIStorageUpgradeable.supportsInterface(interfaceId);
    }

    /**
     * @dev Safely mint a new token
     * @param to Recipient of the token
     * @param tokenId ID of the token to mint
     * @param tokenUri Metadata URI for the token
     */
    function _safeMint(
        address to, 
        uint256 tokenId, 
        string memory tokenUri
    ) internal virtual {
        super._safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenUri);
    }

    /**
     * @dev Burn a token
     * @param tokenId ID of the token to burn
     */
    function _burn(uint256 tokenId) 
        internal 
        virtual 
        override(
            ERC721Upgradeable, 
            ERC721URIStorageUpgradeable
        ) 
    {
        super._burn(tokenId);
    }
}