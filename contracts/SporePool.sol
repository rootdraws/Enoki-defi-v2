// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title ModernSporePool
 * @dev Advanced staking pool with SPORE rewards and Mushroom NFT integration
 * 
 * Features:
 * - Token staking with SPORE rewards
 * - Mushroom NFT minting
 * - Flexible reward distribution
 * - Enhanced security mechanisms
 * 
 * Core Token Flow:
 * Stake → Earn SPORE → Mint Mushrooms → Further Staking
 */
contract ModernSporePool is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable 
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Custom error types for gas-efficient error handling
    error InvalidAmount();
    error StakingNotStarted();
    error InsufficientRewards();
    error InvalidTokenRecovery();
    error UnauthorizedRateChange();

    // Structs for more efficient storage and logic
    struct RewardState {
        uint256 perTokenStored;
        uint256 lastUpdateTime;
    }

    struct UserRewardInfo {
        uint256 paid;
        uint256 pending;
    }

    // Interfaces and core contracts
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

    // Core state variables with improved structure
    IERC20Upgradeable public stakingToken;
    ISporeToken public sporeToken;
    IMushroomFactory public mushroomFactory;
    IMission public mission;

    // Reward configuration
    uint256 public constant MAX_PERCENTAGE = 100;
    uint256 public sporesPerSecond;
    uint256 public devRewardPercentage;

    // Reward tracking
    RewardState private _rewardState;
    mapping(address => UserRewardInfo) private _userRewards;

    // Staking state
    uint256 private _totalStaked;
    mapping(address => uint256) private _userStaked;

    // Addresses
    address public devRewardAddress;
    address public daoRewardAddress;
    address public rateVoteContract;

    /**
     * @dev Initialize the contract with core parameters
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
        bytes memory _initParams
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        // Decode and set initialization parameters
        (
            address _devRewardAddress,
            address _daoRewardAddress,
            uint256 _devRewardPercentage,
            uint256 _initialSporesPerSecond
        ) = abi.decode(_initParams, (address, address, uint256, uint256));

        // Set core contract references
        stakingToken = IERC20Upgradeable(_stakingToken);
        sporeToken = ISporeToken(_sporeToken);
        mushroomFactory = IMushroomFactory(_mushroomFactory);
        mission = IMission(_mission);

        // Set reward and address parameters
        devRewardAddress = _devRewardAddress;
        daoRewardAddress = _daoRewardAddress;
        devRewardPercentage = _devRewardPercentage;
        sporesPerSecond = _initialSporesPerSecond;

        // Initialize reward state
        _rewardState.lastUpdateTime = block.timestamp;
    }

    /**
     * @dev Stake tokens to earn rewards
     * @param amount Amount of tokens to stake
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert InvalidAmount();

        _updateReward(msg.sender);

        _totalStaked += amount;
        _userStaked[msg.sender] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    /**
     * @dev Withdraw staked tokens
     * @param amount Amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) revert InvalidAmount();

        _updateReward(msg.sender);

        _totalStaked -= amount;
        _userStaked[msg.sender] -= amount;

        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @dev Harvest SPORE rewards and mint Mushrooms
     * @param mushroomCount Number of Mushroom NFTs to mint
     */
    function harvest(uint256 mushroomCount) external nonReentrant {
        _updateReward(msg.sender);

        UserRewardInfo storage userReward = _userRewards[msg.sender];
        uint256 pendingReward = userReward.pending;

        if (pendingReward == 0) revert InsufficientRewards();
        if (mushroomCount == 0) revert InvalidAmount();

        uint256 mushroomCost = mushroomFactory.costPerMushroom() * mushroomCount;
        if (pendingReward < mushroomCost) revert InsufficientRewards();

        // Calculate and distribute rewards
        uint256 devReward = (mushroomCost * devRewardPercentage) / MAX_PERCENTAGE;
        uint256 daoReward = mushroomCost - devReward;

        // Send rewards
        if (devReward > 0) {
            mission.sendSpores(devRewardAddress, devReward);
            emit DevRewardPaid(devRewardAddress, devReward);
        }

        mission.sendSpores(daoRewardAddress, daoReward);
        emit DaoRewardPaid(daoRewardAddress, daoReward);

        // Mint Mushrooms
        mushroomFactory.growMushrooms(msg.sender, mushroomCount);

        // Update user's pending rewards
        userReward.pending = pendingReward - mushroomCost;

        emit MushroomsGrown(msg.sender, mushroomCount);
    }

    /**
     * @dev Update reward state for an account
     * @param account Address to update rewards for
     */
    function _updateReward(address account) internal {
        RewardState memory state = _rewardState;
        uint256 currentTime = block.timestamp;
        
        // Calculate new reward per token
        if (_totalStaked > 0) {
            uint256 timeDelta = currentTime - state.lastUpdateTime;
            uint256 newRewardPerToken = state.perTokenStored + 
                (timeDelta * sporesPerSecond * 1e18) / _totalStaked;
            
            _rewardState.perTokenStored = newRewardPerToken;
        }

        _rewardState.lastUpdateTime = currentTime;

        // Update user's pending rewards
        if (account != address(0)) {
            UserRewardInfo storage userReward = _userRewards[account];
            uint256 earnedReward = (_userStaked[account] * 
                (_rewardState.perTokenStored - userReward.paid)) / 1e18;
            
            userReward.pending += earnedReward;
            userReward.paid = _rewardState.perTokenStored;
        }
    }

    /**
     * @dev Change reward rate (restricted to rate vote contract)
     * @param percentage Percentage to adjust rate
     */
    function changeRate(uint256 percentage) external {
        if (msg.sender != rateVoteContract) revert UnauthorizedRateChange();

        sporesPerSecond = (sporesPerSecond * percentage) / MAX_PERCENTAGE;
        emit SporeRateChanged(sporesPerSecond);
    }

    // View functions
    function totalStaked() external view returns (uint256) {
        return _totalStaked;
    }

    function userStaked(address account) external view returns (uint256) {
        return _userStaked[account];
    }

    function pendingRewards(address account) external view returns (uint256) {
        return _userRewards[account].pending;
    }

    // Owner functions
    function recoverTokens(
        address token, 
        uint256 amount
    ) external onlyOwner {
        if (
            token == address(stakingToken) || 
            token == address(sporeToken)
        ) revert InvalidTokenRecovery();

        IERC20Upgradeable(token).safeTransfer(owner(), amount);
        emit TokensRecovered(token, amount);
    }

    function setRateVoteContract(address _contract) external onlyOwner {
        rateVoteContract = _contract;
    }

    // Events
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event DevRewardPaid(address indexed recipient, uint256 amount);
    event DaoRewardPaid(address indexed recipient, uint256 amount);
    event MushroomsGrown(address indexed user, uint256 count);
    event SporeRateChanged(uint256 newRate);
    event TokensRecovered(address token, uint256 amount);
}