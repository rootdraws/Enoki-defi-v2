// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title MushroomLifespanMock
 * @dev Mock contract for testing mushroom lifespan and minting functionality
 * 
 * Imports:
 * - OpenZeppelin: SafeMath, IERC20, SafeERC20, Ownable
 * - Local: MushroomNFT, MushroomLib
 * 
 * Test contract that simulates mushroom minting with randomized lifespans.
 */

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../MushroomNFT.sol";
import "../MushroomLib.sol";

contract MushroomLifespanMock is Initializable, OwnableUpgradeSafe {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;
    using SafeMath for uint256;

    // Counter used for lifespan randomization
    uint256 public spawnCount;

    // Emitted when mushroom is created (for test verification)
    event MushroomGrown(address recipient, uint256 id, uint256 species, uint256 lifespan);

    /**
     * @dev Generates pseudo-random lifespan between min and max values
     * Uses block timestamp + spawn count for randomization
     */
    function generateMushroomLifespan(uint256 minLifespan, uint256 maxLifespan) public returns (uint256) {
        uint256 range = maxLifespan.sub(minLifespan);
        uint256 fromMin = uint256(keccak256(abi.encodePacked(block.timestamp.add(spawnCount)))) % range;
        spawnCount = spawnCount.add(1);

        return minLifespan.add(fromMin);
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
    function growMushrooms(MushroomNFT mushroomNft, uint256 speciesId, address recipient, uint256 numMushrooms) public {
        MushroomLib.MushroomType memory species = mushroomNft.getSpecies(speciesId);

        require(getRemainingMintableForMySpecies(mushroomNft, speciesId) >= numMushrooms, "MushroomFactory: Mushrooms to grow exceeds species cap");
        for (uint256 i = 0; i < numMushrooms; i++) {
            uint256 nextId = mushroomNft.totalSupply().add(1);

            uint256 lifespan = generateMushroomLifespan(species.minLifespan, species.maxLifespan);
            mushroomNft.mint(recipient, nextId, speciesId, lifespan);
            emit MushroomGrown(recipient, nextId, speciesId, lifespan);
        }
    }
}