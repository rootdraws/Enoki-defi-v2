// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title EnokiGeyser
* @dev Modified version of the Geyser staking system for Mushroom NFTs
* 
* Key differences from traditional Geyser:
* - Stakes NFTs instead of LP tokens
* - NFTs have strength (affects rewards) and lifespan
* - NFTs can "die" and get burned
* - 5% of rewards go to dev/chef addresses
* 
* Core Mechanics:
* 1. Users can stake Mushroom NFTs
* 2. Each NFT has:
*    - Strength (determines reward rate)
*    - Lifespan (NFT can "die")
* 3. Rewards:
*    - Based on NFT strength * time staked
*    - Distributed in ENOKI tokens
*    - 5% goes to dev/chef addresses
* 4. When unstaking:
*    - If NFT is dead (lifespan used up) -> burn it
*    - If NFT is alive -> reduce lifespan and return to user
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./TokenPool.sol";
import "./Defensible.sol";
import "./MushroomNFT.sol";
import "./MushroomLib.sol";
import "./metadata/MetadataResolver.sol";

contract EnokiGeyser is Initializable, OwnableUpgradeSafe, AccessControlUpgradeSafe, ReentrancyGuardUpgradeSafe, Defensible {
   using SafeMath for uint256;
   using MushroomLib for MushroomLib.MushroomData;
   using MushroomLib for MushroomLib.MushroomType;

   // Key events for tracking system state
   event Staked(address indexed user, address nftContract, uint256 nftId, uint256 total, bytes data);
   event Unstaked(address indexed user, address nftContract, uint256 nftId, uint256 total, uint256 indexed stakeIndex, bytes data);
   event TokensClaimed(address indexed user, uint256 amount, uint256 userReward, uint256 devReward);
   event LifespanUsed(address nftContract, uint256 nftIndex, uint256 lifespanUsed, uint256 lifespan);
   event NewLifespan(address nftContract, uint256 nftIndex, uint256 lifespan);
   event BurnedMushroom(address nftContract, uint256 nftIndex);

   // Core state variables
   TokenPool public _unlockedPool;
   TokenPool public _lockedPool;
   MetadataResolver public metadataResolver;
   IERC20 public enokiToken;
   uint256 public maxStakesPerAddress;
   
   // Constants
   uint256 public constant SECONDS_PER_WEEK = 604800;
   uint256 public constant MAX_PERCENTAGE = 100;

   // Dev reward configuration
   uint256 public devRewardPercentage = 0; // 0% - 100%
   address public devRewardAddress;

   /**
    * @dev Stake struct represents a single staked NFT
    */
   struct Stake {
       address nftContract;    // NFT contract address
       uint256 nftIndex;      // Token ID
       uint256 strength;      // Affects reward rate
       uint256 stakedAt;      // Timestamp of stake
   }

   // User accounting state
   mapping(address => UserTotals) private _userTotals;
   mapping(address => Stake[]) private _userStakes;

   /**
    * @dev Main staking function - transfers NFT to contract
    */
   function stake(
       address nftContract,
       uint256 nftIndex,
       bytes calldata data
   ) external defend(bannedContractList) {
       require(now > stakingEnabledTime, "staking-too-early");
       require(metadataResolver.isStakeable(nftContract, nftIndex), "EnokiGeyser: nft not stakeable");
       _stakeFor(msg.sender, msg.sender, nftContract, nftIndex);
   }

   /**
    * @dev Main unstaking function - burns or returns NFT based on lifespan
    */
   function _unstake(uint256 stakeIndex)
       private
       returns (
           uint256 totalReward,
           uint256 userReward,
           uint256 devReward
       )
   {
       // Get stake info
       UserTotals storage totals = _userTotals[msg.sender];
       Stake[] storage accountStakes = _userStakes[msg.sender];
       Stake storage currentStake = accountStakes[stakeIndex];

       // Calculate lifespan used and check if mushroom died
       uint256 lifespanUsed = now.sub(currentStake.stakedAt);
       bool deadMushroom = false;

       // Handle dead mushrooms
       if (lifespanUsed >= metadata.lifespan) {
           lifespanUsed = metadata.lifespan;
           deadMushroom = true;
       }

       // Calculate rewards based on strength and time staked
       rewardAmount = computeNewReward(rewardAmount, metadata.strength, lifespanUsed);

       // Burn dead mushrooms or return with reduced lifespan
       if (deadMushroom && metadataResolver.isBurnable(currentStake.nftContract, currentStake.nftIndex)) {
           MushroomNFT(currentStake.nftContract).burn(currentStake.nftIndex);
           emit BurnedMushroom(currentStake.nftContract, currentStake.nftIndex);
       } else {
           metadataResolver.setMushroomLifespan(currentStake.nftContract, currentStake.nftIndex, metadata.lifespan.sub(lifespanUsed), "");
           IERC721(currentStake.nftContract).transferFrom(address(this), msg.sender, currentStake.nftIndex);
       }

       // Calculate and distribute rewards
       (userReward, devReward) = computeDevReward(totalReward);
       
       // Transfer rewards
       if (userReward > 0) {
           require(enokiToken.transfer(msg.sender, userReward));
       }
       if (devReward > 0) {
           require(enokiToken.transfer(devRewardAddress, devReward));
       }
   }

   /**
    * @dev Calculates rewards based on strength and time staked
    */
   function computeNewReward(
       uint256 currentReward,
       uint256 strength,
       uint256 timeStaked
   ) private view returns (uint256) {
       uint256 newReward = strength.mul(timeStaked).div(SECONDS_PER_WEEK);
       return currentReward.add(newReward);
   }
}