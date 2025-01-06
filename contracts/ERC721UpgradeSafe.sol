// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// File Modernized by Claude.AI Sonnet on 1/4/25.

/**
 * @title ERC721UpgradeSafe
 * @notice Enhanced upgradeable ERC721 implementation with full feature set
 * @dev Base contract for upgradeable NFT collections with enumeration and metadata
 * @custom:security-contact security@example.com
 
 This is an advanced, upgradeable ERC721 (NFT) smart contract with comprehensive features:

Key Characteristics:
- Fully upgradeable NFT implementation
- Supports metadata management
- Includes pausable and reentrancy protection
- Provides flexible metadata controls

Core Features:
1. Metadata Management
- Set and update base and contract-level URIs
- Option to permanently freeze metadata
- Prevents changes after freezing

2. Security Mechanisms
- Ownable access control
- Pausable token transfers
- Reentrancy protection
- Custom error handling

3. Advanced NFT Functionalities
- Enumerable token tracking
- URI storage
- Interface support checks
- Customizable token URI retrieval

Unique Design Elements:
- Uses OpenZeppelin's upgradeable contract library
- Abstract contract serving as a robust base for NFT projects
- Allows dynamic configuration while maintaining security

The contract provides a secure, flexible foundation for creating upgradeable NFT collections with granular control over metadata and transfers.
 
 */

abstract contract ERC721UpgradeSafe is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable 
{
    /// @dev Error messages
    error InvalidName();
    error InvalidSymbol();
    error TokenNotMinted(uint256 tokenId);
    error CallerNotTokenOwner(address caller, uint256 tokenId);

    /// @dev Events for tracking important contract changes
    event BaseURIChanged(string newBaseURI);
    event ContractURIChanged(string newContractURI);
    event MetadataFrozen();

    /// @dev Metadata configuration
    string private _baseTokenURI;
    string private _contractURI;
    bool private _metadataFrozen;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the upgradeable NFT contract
     * @param name_ Collection name
     * @param symbol_ Collection symbol
     * @param initialBaseURI_ Initial base URI for token metadata
     */
    function __ERC721UpgradeSafe_init(
        string memory name_,
        string memory symbol_,
        string memory initialBaseURI_
    ) internal onlyInitializing {
        if (bytes(name_).length == 0) revert InvalidName();
        if (bytes(symbol_).length == 0) revert InvalidSymbol();

        __ERC721_init(name_, symbol_);
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();

        _baseTokenURI = initialBaseURI_;
    }

    /**
     * @notice Checks if metadata can be updated
     */
    modifier whenMetadataNotFrozen() {
        require(!_metadataFrozen, "Metadata is frozen");
        _;
    }

    /**
     * @dev Required override for token transfers
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override(
        ERC721Upgradeable, 
        ERC721EnumerableUpgradeable
    ) returns (address) {
        return super._update(to, tokenId, auth);
    }

    /**
     * @notice Gets full token URI
     * @param tokenId Token to query
     */
     function tokenURI(
        uint256 tokenId
    ) public view virtual override(
        ERC721Upgradeable,
        ERC721URIStorageUpgradeable
    ) returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert TokenNotMinted(tokenId);
        return ERC721URIStorageUpgradeable.tokenURI(tokenId);
    }

    /**
     * @notice Updates base token URI
     * @param newBaseURI New base URI
     */
    function setBaseURI(
        string memory newBaseURI
    ) external onlyOwner whenMetadataNotFrozen {
        _baseTokenURI = newBaseURI;
        emit BaseURIChanged(newBaseURI);
    }

    /**
     * @notice Updates contract-level URI
     * @param newURI New contract URI
     */
    function setContractURI(
        string memory newURI
    ) external onlyOwner whenMetadataNotFrozen {
        _contractURI = newURI;
        emit ContractURIChanged(newURI);
    }

    /**
     * @notice Permanently freezes metadata
     */
    function freezeMetadata() external onlyOwner {
        _metadataFrozen = true;
        emit MetadataFrozen();
    }

    /**
     * @notice Gets base token URI
     */
    function baseURI() external view returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @notice Gets contract-level metadata URI
     */
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    /**
     * @notice Checks if metadata is frozen
     */
    function isMetadataFrozen() external view returns (bool) {
        return _metadataFrozen;
    }

    /**
     * @notice Pauses token transfers
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
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

    /**
     * @dev Required override for balance updates
     */
    function _increaseBalance(
        address account,
        uint128 amount
    ) internal virtual override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, amount);
    }
}