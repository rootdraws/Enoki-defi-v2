// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

// External interfaces
interface ISporeToken {
    function mint(address to, uint256 amount) external returns (bool);
}

interface IMission {
    function sendSpores(address recipient, uint256 amount) external returns (bool);
}

/**
 * @title ModernSporePoolEth
 * @notice Advanced ETH staking pool with flexible yield strategies and enhanced security
 * @dev Implements upgradeable patterns with modern safety features
 
 This is an upgradeable ETH staking pool contract called ModernSporePoolEth. Users can stake ETH to earn SPORE token rewards based on a configurable reward rate. The staked ETH can be allocated to different yield strategies such as liquidity providing or lending. The contract includes features like pausability, reentrancy protection, and the ability to update the reward rate and yield strategy. Rewards are distributed among the user, a dev address, and a DAO address. The contract interacts with an external SPORE token contract for minting rewards and a mission contract for additional functionality.
 
 
 */
contract ModernSporePoolEth is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable 
{
    using Address for address payable;
    // Used import "@openzeppelin/contracts/utils/Address.sol"; instead of AddressUpgradeable.sol
    // Could not find AddressUpgradeable Library in @openzeppelin/contracts-upgradeable.

    // Custom errors with descriptive parameters
    error InvalidStakeAmount(uint256 amount);
    error StakingNotStarted(uint256 currentTime, uint256 startTime);
    error InsufficientBalance(uint256 requested, uint256 available);
    error StrategyError(address strategy, string reason);
    error ZeroAddress();
    error InvalidRewardRate();
    error InvalidStrategy(uint8 strategyType);
    error RewardDistributionFailed();
    error TransferFailed();
    error UnauthorizedOperation();

    // Constants
    uint256 public constant MAX_PERCENTAGE = 100;
    uint8 public constant STRATEGY_TYPE_IDLE = 0;
    uint8 public constant STRATEGY_TYPE_LIQUIDITY = 1;
    uint8 public constant STRATEGY_TYPE_LENDING = 2;
    uint8 public constant STRATEGY_TYPE_AGGREGATOR = 3;

    // Structs with explicit types
    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
        uint256 lastUpdateTime;
    }

    struct PoolStrategy {
        address strategyAddress;
        uint256 allocatedAmount;
        uint8 strategyType;
        bool active;
    }

    // State variables
    ISporeToken public sporeToken;
    IMission public mission;

    uint256 public sporesPerSecond;
    uint256 public totalStaked;
    uint256 public stakingStartTime;
    uint256 public lastUpdateTime;

    mapping(address account => StakeInfo info) private _stakes;
    
    PoolStrategy public currentStrategy;
    address public devRewardAddress;
    address public daoRewardAddress;

    // Events with indexed parameters
    event EthStaked(address indexed user, uint256 amount, uint256 totalStaked);
    event EthWithdrawn(address indexed user, uint256 amount, uint256 totalStaked);
    event RewardsHarvested(address indexed user, uint256 amount, uint256 timestamp);
    event StrategyUpdated(
        address indexed oldStrategy,
        address indexed newStrategy,
        uint8 strategyType,
        uint256 timestamp
    );
    event SporeRateChanged(uint256 oldRate, uint256 newRate, uint256 timestamp);
    event RewardsDistributed(
        address indexed user,
        uint256 userShare,
        uint256 devShare,
        uint256 daoShare
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the ETH staking pool
     * @param _initParams Encoded initialization parameters
     */
    function initialize(bytes calldata _initParams) external initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __Pausable_init();

        (
            address _sporeToken,
            address _mission,
            address _devRewardAddress,
            address _daoRewardAddress,
            uint256 _initialSporesPerSecond,
            uint256 _stakingStartTime
        ) = abi.decode(
            _initParams, 
            (address, address, address, address, uint256, uint256)
        );

        if (_sporeToken == address(0) || 
            _mission == address(0) || 
            _devRewardAddress == address(0) || 
            _daoRewardAddress == address(0)) revert ZeroAddress();
            
        if (_initialSporesPerSecond == 0) revert InvalidRewardRate();

        sporeToken = ISporeToken(_sporeToken);
        mission = IMission(_mission);
        devRewardAddress = _devRewardAddress;
        daoRewardAddress = _daoRewardAddress;
        sporesPerSecond = _initialSporesPerSecond;
        stakingStartTime = _stakingStartTime;
        lastUpdateTime = block.timestamp;

        currentStrategy = PoolStrategy({
            strategyAddress: address(0),
            allocatedAmount: 0,
            strategyType: STRATEGY_TYPE_IDLE,
            active: false
        });
    }

    /**
     * @notice Stake ETH to earn SPORE rewards
     */
    function stakeEth() external payable nonReentrant whenNotPaused {
        if (msg.value == 0) revert InvalidStakeAmount(msg.value);
        if (block.timestamp < stakingStartTime) {
            revert StakingNotStarted(block.timestamp, stakingStartTime);
        }

        StakeInfo storage stake = _stakes[msg.sender];
        
        _updateRewards(msg.sender);

        unchecked {
            // Safe because we check for overflow in _updateRewards
            totalStaked += msg.value;
            stake.amount += msg.value;
        }

        if (currentStrategy.active) {
            _deployToStrategy(msg.value);
        }

        emit EthStaked(msg.sender, msg.value, totalStaked);
    }

    /**
     * @notice Withdraw staked ETH
     * @param amount Amount of ETH to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        StakeInfo storage stake = _stakes[msg.sender];

        if (amount == 0) revert InvalidStakeAmount(amount);
        if (amount > stake.amount) {
            revert InsufficientBalance(amount, stake.amount);
        }

        _updateRewards(msg.sender);

        unchecked {
            // Safe due to check above
            totalStaked -= amount;
            stake.amount -= amount;
        }

        if (currentStrategy.active) {
            _withdrawFromStrategy(amount);
        }

        payable(msg.sender).sendValue(amount);

        emit EthWithdrawn(msg.sender, amount, totalStaked);
    }

    /**
     * @notice Harvest SPORE rewards
     */
    function harvestRewards() external nonReentrant whenNotPaused {
        StakeInfo storage stake = _stakes[msg.sender];
        
        _updateRewards(msg.sender);

        uint256 rewards = stake.pendingRewards;
        if (rewards == 0) revert InsufficientBalance(rewards, 0);

        stake.pendingRewards = 0;
        stake.lastUpdateTime = block.timestamp;

        _distributeRewards(msg.sender, rewards);

        emit RewardsHarvested(msg.sender, rewards, block.timestamp);
    }

    /**
     * @notice Update rewards for a user
     * @param account Address to update rewards for
     */
    function _updateRewards(address account) internal {
        StakeInfo storage stake = _stakes[account];
        
        uint256 timeElapsed = block.timestamp - stake.lastUpdateTime;
        if (timeElapsed == 0) return;

        uint256 newRewards = (stake.amount * sporesPerSecond * timeElapsed) / 1e18;
        
        unchecked {
            // Safe as sporesPerSecond is controlled by owner
            stake.pendingRewards += newRewards;
            stake.lastUpdateTime = block.timestamp;
        }
    }

    /**
     * @notice Distribute rewards to user and protocol
     * @param recipient Reward recipient
     * @param totalRewards Total rewards to distribute
     */
    function _distributeRewards(address recipient, uint256 totalRewards) internal {
        uint256 devShare = (totalRewards * 10) / 100;
        uint256 daoShare = (totalRewards * 5) / 100;
        uint256 userShare = totalRewards - devShare - daoShare;

        bool success = true;
        
        if (devShare > 0) {
            success = success && sporeToken.mint(devRewardAddress, devShare);
        }
        
        if (daoShare > 0) {
            success = success && sporeToken.mint(daoRewardAddress, daoShare);
        }
        
        success = success && sporeToken.mint(recipient, userShare);
        
        if (!success) revert RewardDistributionFailed();

        emit RewardsDistributed(recipient, userShare, devShare, daoShare);
    }

    /**
     * @notice Deploy staked ETH to current strategy
     * @param amount Amount to deploy
     */
    function _deployToStrategy(uint256 amount) internal {
        PoolStrategy storage strategy = currentStrategy;
        
        if (strategy.strategyAddress != address(0)) {
            try this.executeStrategyDeposit(strategy.strategyAddress, amount) {
                unchecked {
                    strategy.allocatedAmount += amount;
                }
            } catch Error(string memory reason) {
                revert StrategyError(strategy.strategyAddress, reason);
            }
        }
    }

    /**
     * @notice Withdraw from current strategy
     * @param amount Amount to withdraw
     */
    function _withdrawFromStrategy(uint256 amount) internal {
        PoolStrategy storage strategy = currentStrategy;
        
        if (strategy.strategyAddress != address(0)) {
            try this.executeStrategyWithdraw(strategy.strategyAddress, amount) {
                unchecked {
                    strategy.allocatedAmount -= amount;
                }
            } catch Error(string memory reason) {
                revert StrategyError(strategy.strategyAddress, reason);
            }
        }
    }

    /**
     * @notice Execute strategy deposit
     * @param strategyAddress Strategy contract address
     * @param amount Deposit amount
     */
    function executeStrategyDeposit(
        address strategyAddress,
        uint256 amount
    ) external payable {
        if (msg.sender != address(this)) revert UnauthorizedOperation();
        
        (bool success, ) = strategyAddress.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /**
     * @notice Execute strategy withdrawal
     * @param strategyAddress Strategy contract address
     * @param amount Withdrawal amount
     */
    function executeStrategyWithdraw(
        address strategyAddress,
        uint256 amount
    ) external {
        if (msg.sender != address(this)) revert UnauthorizedOperation();
        
        (bool success, ) = strategyAddress.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /**
     * @notice Update current yield strategy
     * @param newStrategy New strategy contract address
     * @param strategyType Type of strategy
     */
    function updateStrategy(
        address newStrategy, 
        uint8 strategyType
    ) external onlyOwner {
        if (newStrategy == address(0)) revert ZeroAddress();
        if (strategyType > STRATEGY_TYPE_AGGREGATOR) {
            revert InvalidStrategy(strategyType);
        }

        address oldStrategy = currentStrategy.strategyAddress;
        
        if (currentStrategy.allocatedAmount > 0) {
            _withdrawFromStrategy(currentStrategy.allocatedAmount);
        }

        currentStrategy = PoolStrategy({
            strategyAddress: newStrategy,
            allocatedAmount: 0,
            strategyType: strategyType,
            active: true
        });

        emit StrategyUpdated(oldStrategy, newStrategy, strategyType, block.timestamp);
    }

    /**
     * @notice Change SPORE reward rate
     * @param newRate New reward rate
     */
    function changeRewardRate(uint256 newRate) external onlyOwner {
        if (newRate == 0) revert InvalidRewardRate();
        
        uint256 oldRate = sporesPerSecond;
        sporesPerSecond = newRate;
        
        emit SporeRateChanged(oldRate, newRate, block.timestamp);
    }

    /**
     * @notice View functions for user information
     */
    function stakedBalance(address account) external view returns (uint256) {
        return _stakes[account].amount;
    }

    function pendingRewards(address account) external view returns (uint256) {
        StakeInfo storage stake = _stakes[account];
        uint256 timeElapsed = block.timestamp - stake.lastUpdateTime;
        return stake.pendingRewards + ((stake.amount * sporesPerSecond * timeElapsed) / 1e18);
    }

    function getCurrentStrategy() external view returns (
        address strategyAddress,
        uint256 allocatedAmount,
        uint8 strategyType,
        bool active
    ) {
        return (
            currentStrategy.strategyAddress,
            currentStrategy.allocatedAmount,
            currentStrategy.strategyType,
            currentStrategy.active
        );
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;

    receive() external payable {}
}