// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../MushroomLib.sol";
import {MushroomNFT} from "../MushroomNFT.sol";
import {IMushroomFactory} from "../interfaces/IMushroomFactory.sol";

// Still has Errors relating to Lifespan.

/*

This is a mock contract for generating Mushroom NFTs with dynamic lifespan generation:

Key Features:
- Creates Mushroom NFTs for a specific species
- Randomly generates mushroom lifespans
- Implements factory interface for NFT minting
- Tracks remaining mintable NFTs for a species

Core Functionality:
1. Mushroom Generation
- Mint multiple mushrooms to a recipient
- Randomly generate lifespan within species-defined range
- Ensure minting doesn't exceed species limit

2. Randomization Mechanism
- Uses timestamp and spawn count for pseudo-random lifespan
- Incremental spawn count to ensure uniqueness
- Validates lifespan range before generation

3. Security Mechanisms
- Reentrancy protection
- Zero-address checks
- Initializable and upgradeable
- Owner-controlled

Unique Design Elements:
- Integrated with a MushroomNFT contract
- Follows factory pattern for NFT creation
- Supports species-specific minting constraints
- Flexible lifespan generation

The contract provides a controlled, randomized mechanism for creating Mushroom NFTs with varying lifespans in the Enoki ecosystem.
*/

contract MushroomLifespanMock is 
    IMushroomFactory,
    Initializable, 
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable 
{
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    /// @notice Counter used for lifespan randomization
    uint256 private _spawnCount;
    
    /// @notice NFT contract reference
    MushroomNFT public mushroomNft;
    
    /// @notice Species this mock creates
    uint256 private _mySpecies;

    /// @notice Error thrown when lifespan range is invalid
    error InvalidLifespanRange(uint256 min, uint256 max);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the mock
     * @param nft NFT contract address
     * @param speciesId Species to create
     */
    function initialize(
        MushroomNFT nft,
        uint256 speciesId
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        
        mushroomNft = nft;
        _mySpecies = speciesId;
        _spawnCount = 0;
    }

    /**
     * @inheritdoc IMushroomFactory
     */
    function growMushrooms(
        address recipient,
        uint256 numMushrooms
    ) external override nonReentrant returns (uint256[] memory tokenIds) {
        if (recipient == address(0)) revert InvalidRecipient(recipient);
        if (numMushrooms == 0) revert InvalidAmount(0);

        uint256 remaining = getRemainingMintableForSpecies();
        if (remaining < numMushrooms) {
            revert ExceedsSpeciesLimit(numMushrooms, remaining);
        }

        MushroomLib.MushroomType memory species = mushroomNft.getSpecies(_mySpecies);
        tokenIds = new uint256[](numMushrooms);

        for (uint256 i = 0; i < numMushrooms;) {
            uint256 lifespan = generateMushroomLifespan(
                species.minLifespan,
                species.maxLifespan
            );
            
            tokenIds[i] = mushroomNft.mint(recipient, _mySpecies, lifespan);

            unchecked { ++i; }
        }

        emit MushroomsGrown(recipient, tokenIds, _mySpecies);
        return tokenIds;
    }

    /**
     * @notice Generates random lifespan for testing
     * @param minLifespan Minimum lifespan
     * @param maxLifespan Maximum lifespan
     */
    function generateMushroomLifespan(
        uint256 minLifespan,
        uint256 maxLifespan
    ) public returns (uint256) {
        if (maxLifespan <= minLifespan) {
            revert InvalidLifespanRange(minLifespan, maxLifespan);
        }

        uint256 range = maxLifespan - minLifespan;
        uint256 fromMin = uint256(
            keccak256(
                abi.encodePacked(block.timestamp + _spawnCount)
            )
        ) % range;
        
        unchecked {
            _spawnCount++;
        }

        return minLifespan + fromMin;
    }

    /**
     * @inheritdoc IMushroomFactory
     */
    function getRemainingMintableForSpecies() public view override returns (uint256) {
        return mushroomNft.getRemainingMintableForSpecies(_mySpecies);
    }

    /**
     * @inheritdoc IMushroomFactory
     */
    function getFactorySpecies() external view override returns (uint256) {
        return _mySpecies;
    }

    /**
     * @notice Returns current spawn count
     */
    function spawnCount() external view returns (uint256) {
        return _spawnCount;
    }
}