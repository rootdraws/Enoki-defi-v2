// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMushroomFactory {
    function costPerMushroom() external view returns (uint256);
    function getRemainingMintableForMySpecies(uint256 numMushrooms) external view returns (uint256);
    function growMushrooms(address recipient, uint256 numMushrooms) external;

    event MushroomsGrown(address indexed recipient, uint256 numMushrooms);
}