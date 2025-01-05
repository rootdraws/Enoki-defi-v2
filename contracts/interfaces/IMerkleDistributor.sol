// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Now that the bottom contracts are all Modernized, we need to upgrade these Interfaces
// Copy the bottom contracts, and then say, Create an interface for these please, here is the previous interface.

/**
 * @title IMerkleDistributor
 * @notice Interface for claiming tokens using merkle proofs
 * @dev Implements a merkle-based distribution mechanism for token airdrops
 */
interface IMerkleDistributor {
    /**
     * @notice Token distribution claim event
     * @param index Index in the merkle tree
     * @param account Address receiving the claim
     * @param amount Amount of tokens claimed
     * @param tipAmount Amount of tokens given as tip
     */
    event Claimed(
        uint256 indexed index,
        address indexed account,
        uint256 amount,
        uint256 tipAmount
    );

    /**
     * @notice Error thrown when claim proof is invalid
     * @param index Index that was attempted to claim
     * @param account Address attempting to claim
     */
    error InvalidProof(uint256 index, address account);

    /**
     * @notice Error thrown when claim has already been processed
     * @param index Index that was attempted to claim
     */
    error AlreadyClaimed(uint256 index);

    /**
     * @notice Error thrown when tip percentage is too high
     * @param tipBips Attempted tip amount in BIPS
     */
    error TipTooHigh(uint256 tipBips);

    /**
     * @notice Get the address of the token being distributed
     * @return Address of the token contract
     */
    function token() external view returns (address);

    /**
     * @notice Get the merkle root of the distribution tree
     * @return The merkle root hash
     */
    function merkleRoot() external view returns (uint256);

    /**
     * @notice Claim tokens for an account using a merkle proof
     * @param index Index in the merkle tree
     * @param account Address receiving the claim
     * @param amount Amount of tokens to claim
     * @param merkleProof Array of hashes forming the merkle proof
     * @param tipBips Optional tip percentage in BIPS (1 BIP = 0.01%)
     * @param _merkleRoot Expected merkle root (for verification)
     * @dev Reverts if the proof is invalid or claim has been processed
     */
    function claim(
        uint256 index,
        address payable account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint256 tipBips,
        uint256 _merkleRoot
    ) external;

    /**
     * @notice Check if a claim has been processed
     * @param index Index in the merkle tree to check
     * @return True if the index has been claimed
     */
    function isClaimed(uint256 index) external view returns (bool);

    /**
     * @notice Returns the maximum allowed tip in BIPS
     * @return Maximum tip percentage (100 = 1%)
     */
    function MAX_TIP_BIPS() external view returns (uint256);
}