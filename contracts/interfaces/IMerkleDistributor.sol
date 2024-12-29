// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// AIRDROPS | TOKEN DISTRIBUTION MECHANISM

interface IMerkleDistributor {
    // INFO | Returns the address of the token distributed by this contract.
    function token() external view returns (address);
    // INFO | Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32);
    
    // CLAIM | Reverts if the inputs are invalid.
    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof, uint256 tipBips) external;
    // CHECK | Returns true if the index has been marked claimed.
    function isClaimed(uint256 index) external view returns (bool);

    // EVENT | Triggered whenever a call to #claim succeeds.
    event Claimed(uint256 index, address account, uint256 amount);
}
