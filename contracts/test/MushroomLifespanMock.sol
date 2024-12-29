// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../MushroomLib.sol";
import {MushroomNFT} from "../MushroomNFT.sol";

/**
 * @title MushroomLifespanMock
 * @dev Mock contract for testing mushroom lifespan and minting functionality
 * 
 * Test contract that simulates mushroom minting with randomized lifespans.
 */

contract MushroomLifespanMock is Initializable, OwnableUpgradeable {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    // Counter used for lifespan randomization
    uint256 public spawnCount;

    // Emitted when mushroom is created (for test verification)
    event MushroomGrown(address indexed recipient, uint256 id, uint256 species, uint256 lifespan);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract
     */
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        spawnCount = 0;
    }

    /**
     * @dev Generates pseudo-random lifespan between min and max values
     * Uses block timestamp + spawn count for randomization
     */
    function generateMushroomLifespan(uint256 minLifespan, uint256 maxLifespan) public returns (uint256) {
        uint256 range = maxLifespan - minLifespan;
        uint256 fromMin = uint256(keccak256(abi.encodePacked(block.timestamp + spawnCount))) % range;
        spawnCount += 1;

        return minLifespan + fromMin;
    }

    /**
     * @dev Helper to check remaining mintable mushrooms for a species
     */
    function getRemainingMintableForMySpecies(MushroomNFT mushroomNft, uint256 speciesId) public view returns (uint256) {
        return mushroomNft.getRemainingMintableForSpecies(speciesId);
    }

    /**
     * @dev Main test function to mint multiple mushrooms
     * - Validates against species cap
     * - Generates random lifespan for each
     * - Mints NFTs and emits events
     */
    function growMushrooms(
        MushroomNFT mushroomNft, 
        uint256 speciesId, 
        address recipient, 
        uint256 numMushrooms
    ) public {
        MushroomLib.MushroomType memory species = mushroomNft.getSpecies(speciesId);

        require(
            getRemainingMintableForMySpecies(mushroomNft, speciesId) >= numMushrooms, 
            "MushroomFactory: Mushrooms to grow exceeds species cap"
        );
        
        for (uint256 i = 0; i < numMushrooms; i++) {
            uint256 nextId = mushroomNft.totalSupply() + 1;

            uint256 lifespan = generateMushroomLifespan(species.minLifespan, species.maxLifespan);
            mushroomNft.mint(recipient, nextId, speciesId, lifespan);
            emit MushroomGrown(recipient, nextId, speciesId, lifespan);
        }
    }
}