// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../../MushroomNFT.sol";
import "../../MushroomLib.sol";
import "./MetadataAdapter.sol";

/**
 * @title MushroomAdapter
 * @dev Concrete implementation of MetadataAdapter for the MushroomNFT contract
 * 
 * This contract serves as a direct interface to the MushroomNFT contract,
 * handling metadata reading and lifespan modifications. It implements a fixed
 * forwarding mechanism that cannot be modified after initialization.
 *
 * Key features:
 * - Direct integration with MushroomNFT contract
 * - Fixed permission structure set at initialization
 * - All mushrooms are stakeable and burnable by default
 */
contract MushroomAdapter is Initializable, MetadataAdapter {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    // Reference to the main MushroomNFT contract
    MushroomNFT public mushroomNft;

    /**
     * @dev Initializes the contract with NFT contract address and authorized forwarder
     * @param nftContract_ Address of the MushroomNFT contract
     * @param forwardActionsFrom_ Address authorized to modify lifespans
     */
    function initialize(address nftContract_, address forwardActionsFrom_) public initializer {
        mushroomNft = MushroomNFT(nftContract_);
        _setupRole(LIFESPAN_MODIFY_REQUEST_ROLE, forwardActionsFrom_);
    }

    /**
     * @dev Retrieves mushroom metadata from the MushroomNFT contract
     * @param index The token ID to query
     * @param data Unused in this implementation but required by interface
     * @return MushroomData struct containing the mushroom's metadata
     */
    function getMushroomData(uint256 index, bytes calldata data) external override view returns (MushroomLib.MushroomData memory) {
        MushroomLib.MushroomData memory mData = mushroomNft.getMushroomData(index);
        return mData;
    }

    /**
     * @dev Always returns true as all mushrooms are stakeable in this implementation
     * @param nftIndex Unused but required by interface
     * @return bool Always returns true
     */
    function isStakeable(uint256 nftIndex) external override view returns (bool) {
        return true;
    }

    /**
     * @dev Always returns true as all mushrooms are burnable in this implementation
     * @param index Unused but required by interface
     * @return bool Always returns true
     */
    function isBurnable(uint256 index) external override view returns (bool) {
        return true;
    }

    /**
     * @dev Forwards lifespan modification requests to the MushroomNFT contract
     * @param index The token ID to modify
     * @param lifespan The new lifespan value
     * @param data Unused in this implementation but required by interface
     */
    function setMushroomLifespan(
        uint256 index,
        uint256 lifespan,
        bytes calldata data
    ) external override onlyLifespanModifier {
        mushroomNft.setMushroomLifespan(index, lifespan);
    }
}