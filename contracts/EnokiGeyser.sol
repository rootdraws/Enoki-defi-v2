// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {TokenPool} from "./TokenPool.sol";
import {Defensible} from "./Defensible.sol";
import {MushroomNFT} from "./MushroomNFT.sol";
import {MushroomLib} from "./MushroomLib.sol";
import {MetadataResolver} from "./metadata/MetadataResolver.sol";
import {BannedContractList} from "./BannedContractList.sol";

// File Modernized by Claude.AI Sonnet on 1/4/25.

/**
 * @title EnokiGeyser
 * @notice Advanced NFT staking system with unique Mushroom mechanics
 * @dev Implements staking with strength-based rewards and lifespan mechanics
 * @custom:security-contact security@example.com
 
 This is an advanced NFT staking contract for the Enoki ecosystem with sophisticated reward mechanics:

Key Features:
- Stake mushroom NFTs
- Dynamic rewards based on NFT strength
- Multi-stake support
- Batch staking capability
- Dev reward allocation

Core Mechanics:
1. Staking System
- Strength-based reward calculation
- Minimum stake duration
- Maximum stakes per address
- Supports multiple NFT contracts

2. Security Mechanisms
- Reentrancy protection
- Pausable contract
- Banned contract list
- Owner-controlled parameters
- Zero-address checks

3. Reward Distribution
- Flexible dev reward percentage
- Per-stake reward tracking
- Minimum stake duration
- Claim-based reward distribution

Unique Design Elements:
- Uses metadata resolver for NFT attributes
- Supports emergency withdrawals
- Dynamic reward computation
- Comprehensive event logging
- Configurable staking parameters

The contract provides a robust, flexible mechanism for NFT staking with advanced reward and security features in the Enoki DeFi ecosystem.
 
 */

contract EnokiGeyser is Ownable, ReentrancyGuard, Defensible, Pausable {
    using MushroomLib for MushroomLib.MushroomData;
    using MushroomLib for MushroomLib.MushroomType;

    /**
     * @dev Stake struct representing a staked NFT
     */
    struct Stake {
        address nftContract;    // NFT contract address
        uint256 nftIndex;       // Token ID
        uint256 strength;       // Affects reward rate
        uint256 stakedAt;       // Timestamp of stake
        uint256 lastUpdateTime; // Last reward computation time
        uint256 accumulatedRewards; // Accumulated unclaimed rewards
    }

    /// @dev Core system events
    event Staked(
        address indexed user,
        address indexed nftContract,
        uint256 indexed nftId,
        uint256 strength,
        uint256 timestamp,
        bytes data
    );
    
    event Unstaked(
        address indexed user,
        address indexed nftContract,
        uint256 indexed nftId,
        uint256 totalStaked,
        uint256 stakeIndex,
        bytes data
    );
    
    event TokensClaimed(
        address indexed user,
        uint256 totalAmount,
        uint256 userReward,
        uint256 devReward,
        uint256 timestamp
    );
    
    event LifespanUpdated(
        address indexed nftContract,
        uint256 indexed nftIndex,
        uint256 newLifespan,
        uint256 lifespanUsed
    );
    
    event MushroomBurned(
        address indexed nftContract,
        uint256 indexed nftIndex,
        address indexed owner,
        uint256 timestamp
    );

    /// @dev Custom errors
    error StakingNotEnabled();
    error NFTNotStakeable();
    error MaxStakesReached();
    error InvalidPercentage();
    error InvalidAddress();
    error StakeNotFound();
    error NoRewardsAvailable();
    error InsufficientRewards();
    error InvalidStakeIndex();
    error LifespanExceeded();

    /// @dev Constants
    uint256 public constant SECONDS_PER_WEEK = 604_800;
    uint256 public constant MAX_PERCENTAGE = 100;
    uint256 public constant MIN_STAKE_DURATION = 1 days;
    uint256 public constant MAX_STAKES_PER_TX = 20;

    /// @dev Core state variables
    TokenPool public immutable unlockedPool;
    TokenPool public immutable lockedPool;
    MetadataResolver public immutable metadataResolver;
    IERC20 public immutable enokiToken;
    BannedContractList public immutable bannedContractList;

    /// @dev Configuration
    uint256 public maxStakesPerAddress;
    uint256 public immutable stakingEnabledTime;
    uint256 public devRewardPercentage;
    address public devRewardAddress;

    /// @dev User state
    mapping(address => uint256) private _userTotalStaked;
    mapping(address => Stake[]) private _userStakes;
    mapping(address => uint256) private _lastClaimTime;
    mapping(address => uint256) private _totalRewardsClaimed;

    /**
     * @notice Contract constructor
     * @param _enokiToken Token used for rewards
     * @param _metadataResolver Resolver for NFT metadata
     * @param _bannedContractList Security contract list
     */
    constructor(
        IERC20 _enokiToken,
        MetadataResolver _metadataResolver,
        BannedContractList _bannedContractList,
        TokenPool _unlockedPool,
        TokenPool _lockedPool
    ) Ownable(msg.sender) {
        if (address(_enokiToken) == address(0)) revert InvalidAddress();
        if (address(_metadataResolver) == address(0)) revert InvalidAddress();
        if (address(_bannedContractList) == address(0)) revert InvalidAddress();
        if (address(_unlockedPool) == address(0)) revert InvalidAddress();
        if (address(_lockedPool) == address(0)) revert InvalidAddress();

        enokiToken = _enokiToken;
        metadataResolver = _metadataResolver;
        bannedContractList = _bannedContractList;
        unlockedPool = _unlockedPool;
        lockedPool = _lockedPool;
        stakingEnabledTime = block.timestamp + 1 days; // 24h delay
        
        _pause(); // Start paused for safety
    }

    /**
     * @notice Stake an NFT
     * @param nftContract NFT contract address
     * @param nftIndex Token ID to stake
     * @param data Additional staking data
     */
    function stake(
        address nftContract,
        uint256 nftIndex,
        bytes calldata data
    ) external nonReentrant defend(bannedContractList) whenNotPaused {
        if (block.timestamp <= stakingEnabledTime) revert StakingNotEnabled();
        if (!metadataResolver.isStakeable(nftContract, nftIndex)) {
            revert NFTNotStakeable();
        }
        if (_userTotalStaked[msg.sender] >= maxStakesPerAddress) {
            revert MaxStakesReached();
        }

        _stakeFor(msg.sender, nftContract, nftIndex, data);
    }

    /**
     * @notice Batch stake multiple NFTs
     * @param nftContracts Array of NFT contract addresses
     * @param nftIndexes Array of token IDs
     * @param data Additional staking data
     */
    function batchStake(
        address[] calldata nftContracts,
        uint256[] calldata nftIndexes,
        bytes calldata data
    ) external nonReentrant defend(bannedContractList) whenNotPaused {
        if (nftContracts.length != nftIndexes.length) revert InvalidStakeIndex();
        if (nftContracts.length > MAX_STAKES_PER_TX) revert MaxStakesReached();
        
        uint256 length = nftContracts.length;
        for (uint256 i = 0; i < length;) {
            if (!metadataResolver.isStakeable(nftContracts[i], nftIndexes[i])) {
                revert NFTNotStakeable();
            }
            _stakeFor(msg.sender, nftContracts[i], nftIndexes[i], data);
            unchecked { ++i; }
        }
    }

    /**
     * @dev Internal stake implementation
     */
    function _stakeFor(
        address staker,
        address nftContract,
        uint256 nftIndex,
        bytes calldata data
    ) internal {
        uint256 strength = _getMushroomStrength(nftContract, nftIndex);
        
        IERC721(nftContract).transferFrom(staker, address(this), nftIndex);

        Stake memory newStake = Stake({
            nftContract: nftContract,
            nftIndex: nftIndex,
            strength: strength,
            stakedAt: block.timestamp,
            lastUpdateTime: block.timestamp,
            accumulatedRewards: 0
        });

        _userStakes[staker].push(newStake);
        _userTotalStaked[staker] += 1;

        emit Staked(
            staker,
            nftContract,
            nftIndex,
            strength,
            block.timestamp,
            data
        );
    }

    /**
     * @notice Unstake an NFT
     * @param stakeIndex Index of stake to remove
     * @param data Additional unstaking data
     */
    function unstake(
        uint256 stakeIndex,
        bytes calldata data
    ) external nonReentrant whenNotPaused {
        Stake[] storage stakes = _userStakes[msg.sender];
        if (stakeIndex >= stakes.length) revert InvalidStakeIndex();

        Stake memory stake = stakes[stakeIndex];
        
        // Update rewards before unstaking
        _updateRewards(msg.sender, stakeIndex);
        
        // Remove stake by swapping with last element and popping
        stakes[stakeIndex] = stakes[stakes.length - 1];
        stakes.pop();
        
        _userTotalStaked[msg.sender] -= 1;

        // Transfer NFT back to owner
        IERC721(stake.nftContract).transferFrom(
            address(this),
            msg.sender,
            stake.nftIndex
        );

        emit Unstaked(
            msg.sender,
            stake.nftContract,
            stake.nftIndex,
            _userTotalStaked[msg.sender],
            stakeIndex,
            data
        );
    }

    /**
     * @notice Claim accumulated rewards
     */
    function claimRewards() external nonReentrant whenNotPaused {
        uint256 totalRewards = 0;
        Stake[] storage stakes = _userStakes[msg.sender];
        
        for (uint256 i = 0; i < stakes.length;) {
            _updateRewards(msg.sender, i);
            totalRewards += stakes[i].accumulatedRewards;
            stakes[i].accumulatedRewards = 0;
            unchecked { ++i; }
        }

        if (totalRewards == 0) revert NoRewardsAvailable();

        (uint256 userReward, uint256 devReward) = _computeRewardSplit(totalRewards);
        
        // Transfer rewards
        if (userReward > 0) {
            enokiToken.transfer(msg.sender, userReward);
        }
        if (devReward > 0 && devRewardAddress != address(0)) {
            enokiToken.transfer(devRewardAddress, devReward);
        }

        _lastClaimTime[msg.sender] = block.timestamp;
        _totalRewardsClaimed[msg.sender] += totalRewards;

        emit TokensClaimed(
            msg.sender,
            totalRewards,
            userReward,
            devReward,
            block.timestamp
        );
    }

    /**
     * @dev Update rewards for a specific stake
     */
    function _updateRewards(address user, uint256 stakeIndex) internal {
        Stake storage stake = _userStakes[user][stakeIndex];
        uint256 timeStaked = block.timestamp - stake.lastUpdateTime;
        
        if (timeStaked < MIN_STAKE_DURATION) return;

        stake.accumulatedRewards = _computeNewReward(
            stake.accumulatedRewards,
            stake.strength,
            timeStaked
        );
        stake.lastUpdateTime = block.timestamp;
    }

    /**
     * @dev Calculate new reward amount
     */
    function _computeNewReward(
        uint256 currentReward,
        uint256 strength,
        uint256 timeStaked
    ) internal pure returns (uint256) {
        return currentReward + ((strength * timeStaked) / SECONDS_PER_WEEK);
    }

    /**
     * @dev Split reward between user and dev
     */
    function _computeRewardSplit(
        uint256 totalReward
    ) internal view returns (uint256 userReward, uint256 devReward) {
        devReward = (totalReward * devRewardPercentage) / MAX_PERCENTAGE;
        userReward = totalReward - devReward;
    }

    /**
     * @dev Get mushroom strength from metadata
     */
    function _getMushroomStrength(
        address nftContract,
        uint256 nftIndex
    ) internal view returns (uint256) {
        MushroomLib.MushroomData memory mushroomData = metadataResolver.getMushroomData(
            nftContract,
            nftIndex,
            ""
        );
        return mushroomData.strength;
    }

    // View functions

    /**
     * @notice Get all stakes for an address
     */
    function getStakes(
        address user
    ) external view returns (Stake[] memory) {
        return _userStakes[user];
    }

    /**
     * @notice Get total staked count for an address
     */
    function getTotalStaked(
        address user
    ) external view returns (uint256) {
        return _userTotalStaked[user];
    }

    /**
     * @notice Get pending rewards for an address
     */
    function getPendingRewards(
        address user
    ) external view returns (uint256 total, uint256 userShare, uint256 devShare) {
        Stake[] memory stakes = _userStakes[user];
        for (uint256 i = 0; i < stakes.length;) {
            uint256 timeStaked = block.timestamp - stakes[i].lastUpdateTime;
            if (timeStaked >= MIN_STAKE_DURATION) {
                total += _computeNewReward(
                    stakes[i].accumulatedRewards,
                    stakes[i].strength,
                    timeStaked
                );
            }
            unchecked { ++i; }
        }
        (userShare, devShare) = _computeRewardSplit(total);
    }

    // Admin functions

    /**
     * @notice Set dev reward percentage
     */
    function setDevRewardPercentage(
        uint256 _percentage
    ) external onlyOwner {
        if (_percentage > MAX_PERCENTAGE) revert InvalidPercentage();
        devRewardPercentage = _percentage;
    }

    /**
     * @notice Set dev reward address
     */
    function setDevRewardAddress(
        address _address
    ) external onlyOwner {
        if (_address == address(0)) revert InvalidAddress();
        devRewardAddress = _address;
    }

    /**
     * @notice Set maximum stakes per address
     */
    function setMaxStakesPerAddress(
        uint256 _max
    ) external onlyOwner {
        if (_max == 0) revert InvalidStakeIndex();
        maxStakesPerAddress = _max;
    }

    /**
     * @notice Pause contract functionality
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause contract functionality
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdraw function for stuck NFTs
     * @param nftContract NFT contract address
     * @param nftIndex Token ID to recover
     * @param recipient Address to send NFT to
     */
    function emergencyWithdrawNFT(
        address nftContract,
        uint256 nftIndex,
        address recipient
    ) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        IERC721(nftContract).transferFrom(address(this), recipient, nftIndex);
    }

    /**
     * @notice Emergency withdraw function for stuck tokens
     * @param token Token contract address
     * @param amount Amount to withdraw
     * @param recipient Address to send tokens to
     */
    function emergencyWithdrawTokens(
        IERC20 token,
        uint256 amount,
        address recipient
    ) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        if (address(token) == address(0)) revert InvalidAddress();
        token.transfer(recipient, amount);
    }
}