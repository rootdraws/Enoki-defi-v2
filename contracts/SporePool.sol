// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

// External interfaces
interface ISporeToken {
    function mint(address to, uint256 amount) external;
}

interface IMushroomFactory {
    function costPerMushroom() external view returns (uint256);
    function growMushrooms(address recipient, uint256 count) external;
}

interface IMission {
    function sendSpores(address recipient, uint256 amount) external;
}

/**
 * @title ModernSporePool
 * @notice Advanced staking pool with SPORE rewards and Mushroom NFT integration
 * @dev Implements upgradeable patterns with enhanced security and optimization
 */
contract ModernSporePool is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable 
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Custom errors with descriptive parameters
    error InvalidAmount(uint256 amount, string reason);
    error StakingNotStarted(uint256 currentTime, uint256 startTime);
    error InsufficientRewards(uint256 requested, uint256 available);
    error InvalidTokenRecovery(address token);
    error UnauthorizedRateChange(address sender);
    error ZeroAddress();
    error InvalidPercentage(uint256 percentage);

    // Structs with explicit types
    struct RewardState {
        uint256 perTokenStored;
        uint256 lastUpdateTime;
        uint256 accumulatedRewards;
    }

    struct UserRewardInfo {
        uint256 paid;
        uint256 pending;
        uint256 lastClaimTime;
    }

    // Core state variables with explicit grouping
    IERC20 public stakingToken;
    ISporeToken public sporeToken;
    IMushroomFactory public mushroomFactory;
    IMission public mission;

    // Reward configuration
    uint256 public constant MAX_PERCENTAGE = 100;
    uint256 public constant PRECISION = 1e18;
    uint256 public sporesPerSecond;
    uint256 public devRewardPercentage;
    uint256 public startTime;

    // Reward tracking with enhanced precision
    RewardState private _rewardState;
    mapping(address account => UserRewardInfo info) private _userRewards;

    // Staking state
    uint256 private _totalStaked;
    mapping(address account => uint256 amount) private _userStaked;

    // Access control
    address public devRewardAddress;
    address public daoRewardAddress;
    address public rateVoteContract;

    // Events with indexed parameters and timestamps
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, uint256 amount, uint256 timestamp);
    event DevRewardPaid(address indexed recipient, uint256 amount, uint256 timestamp);
    event DaoRewardPaid(address indexed recipient, uint256 amount, uint256 timestamp);
    event MushroomsGrown(address indexed user, uint256 count, uint256 mushroomCost);
    event SporeRateChanged(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event TokensRecovered(address indexed token, uint256 amount, address indexed recipient);
    event RewardsUpdated(address indexed user, uint256 newRewards, uint256 timestamp);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the contract with core parameters
     * @param _stakingToken Token to be staked
     * @param _sporeToken SPORE reward token
     * @param _mushroomFactory Mushroom NFT factory
     * @param _mission SPORE distribution controller
     * @param _initParams Initialization parameters
     */
    function initialize(
        address _stakingToken,
        address _sporeToken,
        address _mushroomFactory,
        address _mission,
        bytes calldata _initParams
    ) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        if (_stakingToken == address(0) || 
            _sporeToken == address(0) || 
            _mushroomFactory == address(0) || 
            _mission == address(0)) revert ZeroAddress();

        (
            address _devRewardAddress,
            address _daoRewardAddress,
            uint256 _devRewardPercentage,
            uint256 _initialSporesPerSecond,
            uint256 _startTime
        ) = abi.decode(
            _initParams, 
            (address, address, uint256, uint256, uint256)
        );

        if (_devRewardAddress == address(0) || 
            _daoRewardAddress == address(0)) revert ZeroAddress();
        if (_devRewardPercentage > MAX_PERCENTAGE) revert InvalidPercentage(_devRewardPercentage);

        stakingToken = IERC20(_stakingToken);
        sporeToken = ISporeToken(_sporeToken);
        mushroomFactory = IMushroomFactory(_mushroomFactory);
        mission = IMission(_mission);

        devRewardAddress = _devRewardAddress;
        daoRewardAddress = _daoRewardAddress;
        devRewardPercentage = _devRewardPercentage;
        sporesPerSecond = _initialSporesPerSecond;
        startTime = _startTime;

        _rewardState.lastUpdateTime = block.timestamp;
    }

    /**
     * @notice Stake tokens to earn rewards
     * @param amount Amount of tokens to stake
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount(amount, "Cannot stake zero");
        if (block.timestamp < startTime) {
            revert StakingNotStarted(block.timestamp, startTime);
        }

        _updateReward(msg.sender);

        unchecked {
            // Safe because total supply is checked in token transfer
            _totalStaked += amount;
            _userStaked[msg.sender] += amount;
        }

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount, block.timestamp);
    }

    /**
     * @notice Withdraw staked tokens
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount(amount, "Cannot withdraw zero");
        if (amount > _userStaked[msg.sender]) {
            revert InvalidAmount(amount, "Insufficient balance");
        }

        _updateReward(msg.sender);

        unchecked {
            // Safe due to check above
            _totalStaked -= amount;
            _userStaked[msg.sender] -= amount;
        }

        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, block.timestamp);
    }

    /**
     * @notice Harvest SPORE rewards and mint Mushrooms
     * @param mushroomCount Number of Mushroom NFTs to mint
     */
    function harvest(uint256 mushroomCount) external nonReentrant whenNotPaused {
        if (mushroomCount == 0) revert InvalidAmount(mushroomCount, "Must mint at least one");
        
        _updateReward(msg.sender);

        UserRewardInfo storage userReward = _userRewards[msg.sender];
        uint256 pendingReward = userReward.pending;
        
        uint256 mushroomCost = mushroomFactory.costPerMushroom() * mushroomCount;
        
        if (pendingReward < mushroomCost) {
            revert InsufficientRewards(mushroomCost, pendingReward);
        }

        // Calculate rewards
        uint256 devReward = (mushroomCost * devRewardPercentage) / MAX_PERCENTAGE;
        uint256 daoReward = mushroomCost - devReward;

        // Update state before external calls
        unchecked {
            // Safe due to check above
            userReward.pending = pendingReward - mushroomCost;
            userReward.lastClaimTime = block.timestamp;
        }

        // External calls after state updates
        if (devReward > 0) {
            mission.sendSpores(devRewardAddress, devReward);
            emit DevRewardPaid(devRewardAddress, devReward, block.timestamp);
        }

        mission.sendSpores(daoRewardAddress, daoReward);
        emit DaoRewardPaid(daoRewardAddress, daoReward, block.timestamp);

        mushroomFactory.growMushrooms(msg.sender, mushroomCount);
        emit MushroomsGrown(msg.sender, mushroomCount, mushroomCost);
    }

    /**
     * @notice Update reward state for an account
     * @param account Address to update rewards for
     */
    function _updateReward(address account) internal {
        RewardState storage state = _rewardState;
        uint256 currentTime = block.timestamp;
        
        if (_totalStaked > 0) {
            uint256 timeDelta = currentTime - state.lastUpdateTime;
            uint256 newRewardPerToken = state.perTokenStored + 
                (timeDelta * sporesPerSecond * PRECISION) / _totalStaked;
            
            state.perTokenStored = newRewardPerToken;
            state.accumulatedRewards += timeDelta * sporesPerSecond;
        }

        state.lastUpdateTime = currentTime;

        if (account != address(0)) {
            UserRewardInfo storage userReward = _userRewards[account];
            uint256 userBalance = _userStaked[account];
            
            if (userBalance > 0) {
                uint256 earnedReward = (userBalance * 
                    (state.perTokenStored - userReward.paid)) / PRECISION;
                
                userReward.pending += earnedReward;
                userReward.paid = state.perTokenStored;
                
                emit RewardsUpdated(account, earnedReward, currentTime);
            }
        }
    }

    /**
     * @notice Change reward rate through governance
     * @param percentage Percentage to adjust rate
     */
    function changeRate(uint256 percentage) external {
        if (msg.sender != rateVoteContract) {
            revert UnauthorizedRateChange(msg.sender);
        }
        if (percentage == 0 || percentage > MAX_PERCENTAGE * 2) {
            revert InvalidPercentage(percentage);
        }

        uint256 oldRate = sporesPerSecond;
        sporesPerSecond = (sporesPerSecond * percentage) / MAX_PERCENTAGE;
        
        emit SporeRateChanged(oldRate, sporesPerSecond, block.timestamp);
    }

    /**
     * @notice View functions with enhanced calculations
     */
    function totalStaked() external view returns (uint256) {
        return _totalStaked;
    }

    function userStaked(address account) external view returns (uint256) {
        return _userStaked[account];
    }

    function pendingRewards(
        address account
    ) external view returns (
        uint256 pending,
        uint256 rewardPerToken,
        uint256 lastUpdate
    ) {
        UserRewardInfo storage userReward = _userRewards[account];
        uint256 userBalance = _userStaked[account];
        
        uint256 currentRewardPerToken = _rewardState.perTokenStored;
        if (_totalStaked > 0) {
            uint256 timeDelta = block.timestamp - _rewardState.lastUpdateTime;
            currentRewardPerToken += (timeDelta * sporesPerSecond * PRECISION) / _totalStaked;
        }
        
        pending = userReward.pending + 
            (userBalance * (currentRewardPerToken - userReward.paid)) / PRECISION;
        rewardPerToken = currentRewardPerToken;
        lastUpdate = _rewardState.lastUpdateTime;
    }

    /**
     * @notice Admin functions with enhanced safety
     */
    function recoverTokens(
        address token,
        uint256 amount
    ) external onlyOwner {
        if (token == address(stakingToken) || token == address(sporeToken)) {
            revert InvalidTokenRecovery(token);
        }
        if (amount == 0) revert InvalidAmount(amount, "Cannot recover zero");

        IERC20(token).safeTransfer(owner(), amount);
        emit TokensRecovered(token, amount, owner());
    }

    function setRateVoteContract(address _contract) external onlyOwner {
        if (_contract == address(0)) revert ZeroAddress();
        rateVoteContract = _contract;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}