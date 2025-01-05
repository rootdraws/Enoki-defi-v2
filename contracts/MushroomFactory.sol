// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./MushroomNFT.sol";
import "./MushroomLib.sol";
import "./interfaces/IMushroomFactory.sol";

// File Modernized by Claude.AI Sonnet on 1/4/25.

contract MushroomFactory is IMushroomFactory, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    /// @notice Error thrown when token address is invalid
    error InvalidTokenAddress(address token);

    /// @notice Error thrown when lifespan range is invalid
    error InvalidLifespanRange(uint256 min, uint256 max);

    /// @notice Error thrown when attempting to collect protected token
    error ProtectedToken(address token);

    /// @notice Core contracts
    IERC20 public immutable sporeToken;
    MushroomNFT public immutable mushroomNft;

    /// @notice Factory configuration
    uint256 public immutable costPerMushroom;
    uint256 private immutable _mySpecies;

    /// @notice Counter for randomization
    uint256 private _spawnCount;

    constructor(
        IERC20 _sporeToken,
        MushroomNFT _mushroomNft,
        address _sporePool,
        uint256 _costPerMushroom,
        uint256 _speciesId
    ) Ownable(_sporePool) {
        if (address(_sporeToken) == address(0)) {
            revert InvalidTokenAddress(address(_sporeToken));
        }
        if (address(_mushroomNft) == address(0)) {
            revert InvalidTokenAddress(address(_mushroomNft));
        }
        
        sporeToken = _sporeToken;
        mushroomNft = _mushroomNft;
        costPerMushroom = _costPerMushroom;
        _mySpecies = _speciesId;
    }

    /**
     * @notice Creates multiple mushrooms
     * @param recipient Recipient address
     * @param numMushrooms Number to create
     * @return tokenIds Array of created token IDs
     */
    function growMushrooms(
        address recipient,
        uint256 numMushrooms
    ) external override nonReentrant onlyOwner returns (uint256[] memory tokenIds) {
        if (recipient == address(0)) revert InvalidRecipient(recipient);
        if (numMushrooms == 0) revert InvalidAmount(0);

        uint256 remaining = getRemainingMintableForSpecies();
        if (remaining < numMushrooms) {
            revert ExceedsSpeciesLimit(numMushrooms, remaining);
        }

        MushroomLib.MushroomType memory species = mushroomNft.getSpecies(_mySpecies);
        tokenIds = new uint256[](numMushrooms);

        for (uint256 i = 0; i < numMushrooms;) {
            uint256 lifespan = _generateMushroomLifespan(
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
     * @notice Generates pseudo-random lifespan
     * @param minLifespan Minimum lifespan value
     * @param maxLifespan Maximum lifespan value
     * @return Random lifespan value within range
     */
    function _generateMushroomLifespan(
        uint256 minLifespan,
        uint256 maxLifespan
    ) internal returns (uint256) {
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
     * @notice Recovers accidentally sent tokens
     * @param token Token to recover
     * @param amount Amount to recover
     */
    function collectDust(
        IERC20 token,
        uint256 amount
    ) external onlyOwner {
        if (address(token) == address(sporeToken)) {
            revert ProtectedToken(address(token));
        }
        token.safeTransfer(owner(), amount);
    }

    /**
     * @notice Returns current spawn count
     */
    function spawnCount() external view returns (uint256) {
        return _spawnCount;
    }
}