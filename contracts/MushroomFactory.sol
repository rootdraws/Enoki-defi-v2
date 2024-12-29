// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./MushroomNFT.sol";
import "./MushroomLib.sol";

/**
 * @title MushroomFactory
 * @notice Manages creation and attributes of Mushroom NFTs
 * @dev Supports species-specific NFT minting with controlled randomization
 * 
 * Key Features:
 * - Species-specific factories
 * - NFT minting control
 * - Pseudo-random trait generation
 * - Pool integration
 * 
 * Future VRF Integration:
 * - Chainlink VRF for true randomness
 * - Improved security against manipulation
 */
contract MushroomFactory is Ownable {
    using SafeERC20 for IERC20;
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    // Events
    event MushroomGrown(
        address indexed recipient, 
        uint256 id, 
        uint256 species, 
        uint256 lifespan
    );

    // Core contract references
    IERC20 public immutable sporeToken;
    MushroomNFT public immutable mushroomNft;

    // Minting parameters
    uint256 public immutable costPerMushroom;
    uint256 public immutable mySpecies;

    // Randomization counter
    uint256 private _spawnCount;

    /**
     * @notice Constructor sets up the Mushroom Factory
     * @param _sporeToken SPORE token contract
     * @param _mushroomNft Mushroom NFT contract
     * @param _sporePool Address of the SPORE pool (initial owner)
     * @param _costPerMushroom Cost to mint a mushroom
     * @param _mySpecies Specific species for this factory
     */
    constructor(
        IERC20 _sporeToken,
        MushroomNFT _mushroomNft,
        address _sporePool,
        uint256 _costPerMushroom,
        uint256 _mySpecies
    ) Ownable(_sporePool) {
        require(address(_sporeToken) != address(0), "Invalid SPORE token");
        require(address(_mushroomNft) != address(0), "Invalid Mushroom NFT");
        
        sporeToken = _sporeToken;
        mushroomNft = _mushroomNft;
        costPerMushroom = _costPerMushroom;
        mySpecies = _mySpecies;
    }

    /**
     * @notice Generate pseudo-random mushroom lifespan
     * @param minLifespan Minimum possible lifespan
     * @param maxLifespan Maximum possible lifespan
     * @return Randomly generated lifespan
     */
    function _generateMushroomLifespan(
        uint256 minLifespan, 
        uint256 maxLifespan
    ) internal returns (uint256) {
        uint256 range = maxLifespan - minLifespan;
        uint256 fromMin = uint256(
            keccak256(abi.encodePacked(block.timestamp + _spawnCount))
        ) % range;
        _spawnCount += 1;
        return minLifespan + fromMin;
    }

    /**
     * @notice Check remaining mintable mushrooms for this species
     * @return Number of mushrooms still available to mint
     */
    function getRemainingMintableForMySpecies() public view returns (uint256) {
        return mushroomNft.getRemainingMintableForSpecies(mySpecies);
    }

    /**
     * @notice Mint multiple mushrooms of this species
     * @param recipient Address to receive the mushrooms
     * @param numMushrooms Number of mushrooms to mint
     */
    function growMushrooms(
        address recipient, 
        uint256 numMushrooms
    ) external onlyOwner {
        // Retrieve species details
        MushroomLib.MushroomType memory species = mushroomNft.getSpecies(mySpecies);

        // Validate minting capacity
        require(
            getRemainingMintableForMySpecies() >= numMushrooms, 
            "Exceeds species minting cap"
        );

        // Mint mushrooms
        for (uint256 i = 0; i < numMushrooms; i++) {
            uint256 nextId = mushroomNft.totalSupply() + 1;
            uint256 lifespan = _generateMushroomLifespan(
                species.minLifespan, 
                species.maxLifespan
            );
            
            mushroomNft.mint(recipient, nextId, mySpecies, lifespan);
            
            emit MushroomGrown(recipient, nextId, mySpecies, lifespan);
        }
    }

    /**
     * @notice Optional method to collect any tokens accidentally sent to contract
     * @param token Address of the token to collect
     * @param amount Amount of tokens to collect
     */
    function collectDust(IERC20 token, uint256 amount) external onlyOwner {
        require(token != sporeToken, "Cannot collect SPORE token");
        token.safeTransfer(owner(), amount);
    }
}