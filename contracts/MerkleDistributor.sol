// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MerkleDistributor
 * @notice Handles token distribution using Merkle proofs for efficient airdrop claims
 * 
 * Use Cases:
 * - Community Rewards
 * - Protocol Incentives
 * - NFT Holder Benefits
 * - Marketing/Growth Initiatives
 */
contract MerkleDistributor is Ownable {
    using SafeERC20 for IERC20;

    // Immutable state variables
    IERC20 public immutable token;
    bytes32 public immutable merkleRoot;
    address public immutable daoTreasury;
    uint256 public immutable daoReleaseTime;

    // Bitmap of claimed indices for gas-efficient tracking
    mapping(uint256 => uint256) private _claimedBitMap;

    // Events
    event Claimed(uint256 indexed index, address indexed account, uint256 amount);
    event UnclaimedTokensTransferred(uint256 amount);
    event DustCollected(address indexed token, uint256 amount);

    /**
     * @notice Constructor sets up the distributor
     * @param _token Address of token to distribute
     * @param _merkleRoot Root of merkle tree containing claims
     * @param _daoTreasury Address to receive unclaimed tokens
     * @param _daoReleaseTime When unclaimed tokens can go to DAO
     */
    constructor(
        IERC20 _token,
        bytes32 _merkleRoot,
        address _daoTreasury,
        uint256 _daoReleaseTime
    ) Ownable(msg.sender) {
        require(_daoTreasury != address(0), "Invalid DAO address");
        
        token = _token;
        merkleRoot = _merkleRoot;
        daoTreasury = _daoTreasury;
        daoReleaseTime = _daoReleaseTime;
    }

    /**
     * @notice Check if a specific claim index has been processed
     * @param index Index in merkle tree to check
     * @return Whether the index has been claimed
     */
    function isClaimed(uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = _claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    /**
     * @dev Marks a claim as processed in the bitmap
     * @param index Index to mark as claimed
     */
    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        _claimedBitMap[claimedWordIndex] |= (1 << claimedBitIndex);
    }

    /**
     * @notice Process a token claim with optional tip
     * @param index Index in merkle tree
     * @param account Address to receive tokens
     * @param amount Amount of tokens to claim
     * @param merkleProof Proof of claim validity
     * @param tipBips Optional tip to contract owner (in basis points)
     */
    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint256 tipBips
    ) external {
        require(tipBips <= 10_000, "Tip exceeds 100%");
        require(!isClaimed(index), "Claim already processed");

        // Verify merkle proof
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "Invalid claim proof"
        );

        // Process claim and optional tip
        _setClaimed(index);
        
        uint256 tip = account == msg.sender ? (amount * tipBips) / 10_000 : 0;
        uint256 claimAmount = amount - tip;

        // Transfer tokens
        token.safeTransfer(account, claimAmount);
        if (tip > 0) {
            token.safeTransfer(owner(), tip);
        }

        emit Claimed(index, account, amount);
    }

    /**
     * @notice Transfer unclaimed tokens to DAO after release time
     */
    function transferUnclaimedToDao() external {
        require(block.timestamp >= daoReleaseTime, "Release time not reached");
        
        uint256 remainingBalance = token.balanceOf(address(this));
        token.safeTransfer(daoTreasury, remainingBalance);

        emit UnclaimedTokensTransferred(remainingBalance);
    }

    /**
     * @notice Collect tokens accidentally sent to contract
     * @param _token Token address to collect (address(0) for ETH)
     * @param _amount Amount to collect
     */
    function collectDust(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(token), "Cannot collect distribution token");
        
        if (_token == address(0)) {
            // Collect ETH
            payable(owner()).transfer(_amount);
        } else {
            // Collect ERC20 tokens
            IERC20(_token).safeTransfer(owner(), _amount);
        }

        emit DustCollected(_token, _amount);
    }

    /**
     * @notice Check contract's token balance
     * @return Current balance of distribution token
     */
    function availableTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}