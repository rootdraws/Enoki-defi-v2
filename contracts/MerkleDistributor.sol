// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title MerkleDistributor
* @dev Handles token distribution using Merkle proofs for efficient airdrop claims
* 
* Common Use Cases:
* 1. Community Rewards:
*    - Early community members/users
*    - Discord/Twitter engagement rewards
*    - Early liquidity providers
*
* 2. Protocol Incentives:
*    - Retroactive airdrops for protocol usage
*    - Governance token distribution
*    - Cross-protocol incentives (e.g., using other DeFi protocols)
*
* 3. NFT Holder Benefits:
*    - Token airdrops to NFT holders
*    - Special event participation rewards
*    - Staking rewards distribution
* 
* 4. Marketing/Growth:
*    - Initial token distribution
*    - Partnership rewards
*    - Community expansion initiatives
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IMerkleDistributor.sol";

contract MerkleDistributor is IMerkleDistributor {
   // Immutable state variables
   address public immutable override token;        // Token being distributed
   bytes32 public immutable override merkleRoot;   // Root of merkle tree containing claims
   address public immutable dao;                   // DAO address for unclaimed tokens
   uint256 public immutable daoReleaseTime;       // When unclaimed tokens can go to DAO
   address deployer;                              // Contract deployer address

   // Bitmap of claimed indices for gas-efficient tracking
   mapping(uint256 => uint256) private claimedBitMap;

   /**
    * @dev Sets up the distributor with token and merkle details
    * @param token_ Address of token to distribute
    * @param merkleRoot_ Root of merkle tree containing claims
    * @param dao_ Address to receive unclaimed tokens
    * @param releaseTime_ When unclaimed tokens can go to DAO
    * @param deployer_ Address that can collect dust and trigger DAO release
    */
   constructor(
       address token_,
       bytes32 merkleRoot_,
       address dao_,
       uint256 releaseTime_,
       address deployer_
   ) public {
       token = token_;
       merkleRoot = merkleRoot_;
       deployer = deployer_;
       dao = dao_;
       daoReleaseTime = releaseTime_;
   }

   /**
    * @dev Checks if a claim has been processed
    * @param index Index in merkle tree to check
    */
   function isClaimed(uint256 index) public override view returns (bool) {
       uint256 claimedWordIndex = index / 256;
       uint256 claimedBitIndex = index % 256;
       uint256 claimedWord = claimedBitMap[claimedWordIndex];
       uint256 mask = (1 << claimedBitIndex);
       return claimedWord & mask == mask;
   }

   /**
    * @dev Marks a claim as processed in the bitmap
    * Gas efficient using bit manipulation
    * @param index Index to mark as claimed
    */
   function _setClaimed(uint256 index) private {
       uint256 claimedWordIndex = index / 256;
       uint256 claimedBitIndex = index % 256;
       claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
   }

   /**
    * @dev Process a token claim with optional tip
    * Can be used for:
    * - Initial token distribution
    * - Reward claims
    * - Protocol incentives
    * - NFT holder benefits
    * 
    * @param index Index in merkle tree
    * @param account Address to receive tokens
    * @param amount Amount of tokens to claim
    * @param merkleProof Proof of claim validity
    * @param tipBips Optional tip to deployer (in bips, max 10000 = 100%)
    */
   function claim(
       uint256 index,
       address account,
       uint256 amount,
       bytes32[] calldata merkleProof,
       uint256 tipBips
   ) external override {
       require(tipBips <= 10000);
       require(!isClaimed(index), "MerkleDistributor: Drop already claimed.");

       // Verify merkle proof
       bytes32 node = keccak256(abi.encodePacked(index, account, amount));
       require(
           MerkleProof.verify(merkleProof, merkleRoot, node),
           "MerkleDistributor: Invalid proof."
       );

       // Process claim and optional tip
       _setClaimed(index);
       uint256 tip = account == msg.sender ? (amount * tipBips) / 10000 : 0;
       require(
           IERC20(token).transfer(account, amount - tip),
           "MerkleDistributor: Transfer failed."
       );
       if (tip > 0) require(IERC20(token).transfer(deployer, tip));

       emit Claimed(index, account, amount);
   }

   /**
    * @dev Send unclaimed tokens to DAO after release time
    * Ensures no tokens are lost if users don't claim
    */
   function unclaimedToDao() external {
       require(msg.sender == deployer, "!deployer");
       require(now >= daoReleaseTime, "before unclaimed release time");
       IERC20 enoki = IERC20(token);
       uint256 remainingUnclaimed = enoki.balanceOf(address(this));
       enoki.transfer(dao, remainingUnclaimed);
   }

   /**
    * @dev Collect any non-airdrop tokens sent to contract
    * Safety feature for recovering wrong tokens
    * @param _token Token address to collect (address(0) for ETH)
    * @param _amount Amount to collect
    */
   function collectDust(address _token, uint256 _amount) external {
       require(msg.sender == deployer, "!deployer");
       require(_token != token, "!token");
       if (_token == address(0)) {
           // ETH collection
           payable(deployer).transfer(_amount);
       } else {
           // ERC20 token collection
           IERC20(_token).transfer(deployer, _amount);
       }
   }
}