// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./TokenPool.sol";
import "./Defensible.sol";
import "./MushroomNFT.sol";
import "./MushroomLib.sol";
import "./metadata/MetadataResolver.sol";
import "./BannedContractList.sol";

/**
 * @title EnokiGeyser
 * @notice Modified Geyser staking system for Mushroom NFTs
 * @dev Implements NFT staking with unique mechanics
 * 
 * Key differences from traditional Geyser:
 * - Stakes NFTs instead of LP tokens
 * - NFTs have strength (affects rewards) and lifespan
 * - NFTs can "die" and get burned
 * - Portion of rewards go to dev/chef addresses
 */
contract EnokiGeyser is Ownable, ReentrancyGuard, Defensible {
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
    TokenPool public unlockedPool;
    TokenPool public lockedPool;
    MetadataResolver public metadataResolver;
    IERC20 public enokiToken;
    BannedContractList public bannedContractList;

    // Stake configuration
    uint256 public maxStakesPerAddress;
    uint256 public stakingEnabledTime;

    // Constants
    uint256 public constant SECONDS_PER_WEEK = 604_800;
    uint256 public constant MAX_PERCENTAGE = 100;

    // Dev reward configuration
    uint256 public devRewardPercentage;
    address public devRewardAddress;

    /**
     * @dev Stake struct represents a single staked NFT
     */
    struct Stake {
        address nftContract;    // NFT contract address
        uint256 nftIndex;       // Token ID
        uint256 strength;       // Affects reward rate
        uint256 stakedAt;       // Timestamp of stake
    }

    // User accounting state
    mapping(address => uint256) private _userTotalStaked;
    mapping(address => Stake[]) private _userStakes;

    constructor(
        IERC20 _enokiToken,
        MetadataResolver _metadataResolver,
        BannedContractList _bannedContractList
    ) Ownable(msg.sender) {
        enokiToken = _enokiToken;
        metadataResolver = _metadataResolver;
        bannedContractList = _bannedContractList;
    }

    /**
     * @notice Stake an NFT
     * @dev Transfers NFT to contract and records stake
     */
    function stake(
        address nftContract,
        uint256 nftIndex,
        bytes calldata data
    ) external nonReentrant defend(bannedContractList) {
        require(block.timestamp > stakingEnabledTime, "Staking not yet enabled");
        require(metadataResolver.isStakeable(nftContract, nftIndex), "NFT not stakeable");
        
        _stakeFor(msg.sender, nftContract, nftIndex, data);
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
        // Implement stake logic
        // Transfer NFT, record stake, update user totals
        IERC721(nftContract).transferFrom(staker, address(this), nftIndex);

        Stake memory newStake = Stake({
            nftContract: nftContract,
            nftIndex: nftIndex,
            strength: _getMushroomStrength(nftContract, nftIndex),
            stakedAt: block.timestamp
        });

        _userStakes[staker].push(newStake);
        _userTotalStaked[staker] += 1;

        emit Staked(staker, nftContract, nftIndex, _userTotalStaked[staker], data);
    }

    /**
     * @dev Retrieves mushroom strength from metadata resolver
     */
    function _getMushroomStrength(address nftContract, uint256 nftIndex) internal view returns (uint256) {
        MushroomLib.MushroomData memory mushroomData = metadataResolver.getMushroomData(
            nftContract, 
            nftIndex, 
            ""  // Optional additional data
        );
        return mushroomData.strength;
    }

    /**
     * @dev Calculates rewards based on strength and time staked
     */
    function computeNewReward(
        uint256 currentReward,
        uint256 strength,
        uint256 timeStaked
    ) internal pure returns (uint256) {
        uint256 newReward = (strength * timeStaked) / SECONDS_PER_WEEK;
        return currentReward + newReward;
    }

    /**
     * @dev Compute dev and user rewards
     */
    function computeDevReward(uint256 totalReward) internal view returns (uint256 userReward, uint256 devReward) {
        devReward = (totalReward * devRewardPercentage) / MAX_PERCENTAGE;
        userReward = totalReward - devReward;
    }

    /**
     * @notice Set dev reward percentage
     * @dev Allows owner to adjust dev reward rate
     */
    function setDevRewardPercentage(uint256 _percentage) external onlyOwner {
        require(_percentage <= MAX_PERCENTAGE, "Invalid percentage");
        devRewardPercentage = _percentage;
    }

    /**
     * @notice Set dev reward address
     * @dev Allows owner to change dev reward recipient
     */
    function setDevRewardAddress(address _address) external onlyOwner {
        require(_address != address(0), "Invalid address");
        devRewardAddress = _address;
    }
}