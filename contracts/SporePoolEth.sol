// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title ModernSporePoolEth
 * @dev Advanced ETH staking pool with flexible yield strategies
 * 
 * Key Features:
 * - Native ETH staking
 * - Modular yield generation
 * - SPORE rewards
 * - Flexible strategy management
 * 
 * Potential Yield Sources:
 * 1. Liquidity Provision
 * 2. Lending Markets
 * 3. Yield Aggregation
 * 4. Structured Products
 */
contract ModernSporePoolEth is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    PausableUpgradeable 
{
    // Custom error types for gas-efficient error handling
    error InvalidStakeAmount();
    error StakingNotStarted();
    error InsufficientBalance();
    error StrategyError();
    error UnsupportedOperation();

    // Interfaces for external interactions
    interface ISporeToken {
        function mint(address to, uint256 amount) external;
    }

    interface IMission {
        function sendSpores(address recipient, uint256 amount) external;
    }

    // Structs for more efficient storage and logic
    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    struct PoolStrategy {
        address strategyAddress;
        uint256 allocatedAmount;
        uint8 strategyType; // 0: Idle, 1: LiquidityPool, 2: Lending, 3: Aggregator
    }

    // Core state variables
    ISporeToken public sporeToken;
    IMission public mission;

    // Staking and reward parameters
    uint256 public constant MAX_PERCENTAGE = 100;
    uint256 public sporesPerSecond;
    uint256 public totalStaked;
    uint256 public stakingStartTime;

    // User and reward tracking
    mapping(address => StakeInfo) private _stakes;
    
    // Strategy management
    PoolStrategy public currentStrategy;
    address public devRewardAddress;
    address public daoRewardAddress;

    // Events for tracking key actions
    event EthStaked(address indexed user, uint256 amount);
    event EthWithdrawn(address indexed user, uint256 amount);
    event RewardsHarvested(address indexed user, uint256 amount);
    event StrategyUpdated(address newStrategy, uint8 strategyType);
    event SporeRateChanged(uint256 newRate);

    /**
     * @dev Initialize the ETH staking pool
     * @param _initParams Encoded initialization parameters
     */
    function initialize(bytes memory _initParams) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        // Decode initialization parameters
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

        // Set core contract references
        sporeToken = ISporeToken(_sporeToken);
        mission = IMission(_mission);
        devRewardAddress = _devRewardAddress;
        daoRewardAddress = _daoRewardAddress;

        // Set initial parameters
        sporesPerSecond = _initialSporesPerSecond;
        stakingStartTime = _stakingStartTime;

        // Initialize default strategy (idle)
        currentStrategy = PoolStrategy({
            strategyAddress: address(0),
            allocatedAmount: 0,
            strategyType: 0
        });
    }

    /**
     * @dev Stake ETH to earn SPORE rewards
     */
    function stakeEth() external payable nonReentrant whenNotPaused {
        if (msg.value == 0) revert InvalidStakeAmount();
        if (block.timestamp < stakingStartTime) revert StakingNotStarted();

        // Update user's stake
        StakeInfo storage stake = _stakes[msg.sender];
        
        // Calculate and update rewards
        _updateRewards(msg.sender);

        // Update total and user stake
        totalStaked += msg.value;
        stake.amount += msg.value;

        // Deploy to current strategy if exists
        _deployToStrategy(msg.value);

        emit EthStaked(msg.sender, msg.value);
    }

    /**
     * @dev Withdraw staked ETH
     * @param amount Amount of ETH to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        StakeInfo storage stake = _stakes[msg.sender];

        if (amount == 0) revert InvalidStakeAmount();
        if (amount > stake.amount) revert InsufficientBalance();

        // Update rewards and stake
        _updateRewards(msg.sender);

        totalStaked -= amount;
        stake.amount -= amount;

        // Withdraw from strategy if necessary
        _withdrawFromStrategy(amount);

        // Transfer ETH
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit EthWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Harvest SPORE rewards
     */
    function harvestRewards() external nonReentrant {
        StakeInfo storage stake = _stakes[msg.sender];
        
        _updateRewards(msg.sender);

        uint256 rewards = stake.pendingRewards;
        if (rewards == 0) revert InsufficientBalance();

        // Reset pending rewards
        stake.pendingRewards = 0;

        // Distribute rewards
        _distributeRewards(msg.sender, rewards);

        emit RewardsHarvested(msg.sender, rewards);
    }

    /**
     * @dev Update rewards for a user
     * @param account Address to update rewards for
     */
    function _updateRewards(address account) internal {
        StakeInfo storage stake = _stakes[account];
        
        // Calculate rewards based on stake and time
        uint256 currentTime = block.timestamp;
        uint256 timeDelta = currentTime - stakingStartTime;
        uint256 pendingReward = (stake.amount * sporesPerSecond * timeDelta) / 1e18;

        stake.pendingRewards += pendingReward;
    }

    /**
     * @dev Distribute rewards to user and protocol
     * @param recipient Reward recipient
     * @param totalRewards Total rewards to distribute
     */
    function _distributeRewards(address recipient, uint256 totalRewards) internal {
        // Calculate dev and DAO shares
        uint256 devShare = (totalRewards * 10) / 100; // 10% to dev
        uint256 daoShare = (totalRewards * 5) / 100;  // 5% to DAO
        uint256 userShare = totalRewards - devShare - daoShare;

        // Mint SPORE tokens
        if (devShare > 0) {
            sporeToken.mint(devRewardAddress, devShare);
        }
        
        if (daoShare > 0) {
            sporeToken.mint(daoRewardAddress, daoShare);
        }
        
        sporeToken.mint(recipient, userShare);
    }

    /**
     * @dev Deploy staked ETH to current strategy
     * @param amount Amount to deploy
     */
    function _deployToStrategy(uint256 amount) internal {
        PoolStrategy storage strategy = currentStrategy;
        
        if (strategy.strategyAddress != address(0)) {
            try this.executeStrategyDeposit(strategy.strategyAddress, amount) {
                strategy.allocatedAmount += amount;
            } catch {
                // Fallback to idle if strategy deployment fails
                revert StrategyError();
            }
        }
    }

    /**
     * @dev Withdraw from current strategy
     * @param amount Amount to withdraw
     */
    function _withdrawFromStrategy(uint256 amount) internal {
        PoolStrategy storage strategy = currentStrategy;
        
        if (strategy.strategyAddress != address(0)) {
            try this.executeStrategyWithdraw(strategy.strategyAddress, amount) {
                strategy.allocatedAmount -= amount;
            } catch {
                revert StrategyError();
            }
        }
    }

    /**
     * @dev Execute strategy deposit (external to allow try-catch)
     * @param strategyAddress Strategy contract address
     * @param amount Deposit amount
     */
    function executeStrategyDeposit(address strategyAddress, uint256 amount) external {
        // Placeholder for strategy-specific deposit logic
        // In a real implementation, this would interact with specific protocols
        (bool success, ) = strategyAddress.call{value: amount}("");
        require(success, "Strategy deposit failed");
    }

    /**
     * @dev Execute strategy withdrawal (external to allow try-catch)
     * @param strategyAddress Strategy contract address
     * @param amount Withdrawal amount
     */
    function executeStrategyWithdraw(address strategyAddress, uint256 amount) external {
        // Placeholder for strategy-specific withdrawal logic
        // In a real implementation, this would interact with specific protocols
        (bool success, ) = strategyAddress.call{value: amount}("");
        require(success, "Strategy withdrawal failed");
    }

    /**
     * @dev Update current yield strategy
     * @param newStrategy New strategy contract address
     * @param strategyType Type of strategy
     */
    function updateStrategy(
        address newStrategy, 
        uint8 strategyType
    ) external onlyOwner {
        // Withdraw from current strategy
        if (currentStrategy.allocatedAmount > 0) {
            _withdrawFromStrategy(currentStrategy.allocatedAmount);
        }

        // Update strategy
        currentStrategy = PoolStrategy({
            strategyAddress: newStrategy,
            allocatedAmount: 0,
            strategyType: strategyType
        });

        emit StrategyUpdated(newStrategy, strategyType);
    }

    /**
     * @dev Change SPORE reward rate
     * @param newRate New reward rate
     */
    function changeRewardRate(uint256 newRate) external onlyOwner {
        sporesPerSecond = newRate;
        emit SporeRateChanged(newRate);
    }

    /**
     * @dev Retrieve user's staked amount
     * @param account User address
     * @return Staked amount
     */
    function stakedBalance(address account) external view returns (uint256) {
        return _stakes[account].amount;
    }

    /**
     * @dev Retrieve user's pending rewards
     * @param account User address
     * @return Pending rewards
     */
    function pendingRewards(address account) external view returns (uint256) {
        return _stakes[account].pendingRewards;
    }

    // Allow contract to receive ETH
    receive() external payable {}
}