// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title SporePool
* @dev Main staking pool contract where users:
* 1. Stake tokens to earn SPORE rewards
* 2. Use SPORE to grow Mushroom NFTs
* 3. Earn rewards based on staked amount and time
*
* Key Features:
* - Staking rewards in SPORE tokens
* - SPORE can be used to mint Mushroom NFTs
* - DAO and dev reward distributions
* - Rate adjustable through voting
* - Emergency withdrawal option

SporePool (Base & ETH variant)
├── Stake ETH/tokens
├── Generate SPORE rewards
├── Interface with Mission system
└── Rate adjustment via voting

Mission System
├── SPORE distribution control
├── Pool approval system
└── Treasury management

TOKEN FLOW

ETH Staking → Earn SPORE → Mint Mushrooms → Stake in Geyser → Earn ENOKI

*/

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Defensible.sol";
import "./interfaces/IMushroomFactory.sol";
import "./interfaces/IMission.sol";
import "./interfaces/IMiniMe.sol";
import "./interfaces/ISporeToken.sol";
import "./BannedContractList.sol";

contract SporePool is OwnableUpgradeSafe, ReentrancyGuardUpgradeSafe, PausableUpgradeSafe, Defensible {
   using SafeERC20 for IERC20;

   /* ========== STATE VARIABLES ========== */

   // Core contracts
   ISporeToken public sporeToken;           // SPORE reward token
   IERC20 public stakingToken;              // Token being staked
   IMushroomFactory public mushroomFactory; // For minting mushrooms
   IMission public mission;                 // Controls SPORE distribution
   BannedContractList public bannedContractList;
   IMiniMe public enokiToken;
   
   // Reward tracking
   uint256 public sporesPerSecond = 0;      // Current reward rate
   uint256 public lastUpdateTime;           // Last reward update
   uint256 public rewardPerTokenStored;     // Accumulated rewards per token

   // Reward distribution
   uint256 public constant MAX_PERCENTAGE = 100;
   uint256 public devRewardPercentage;      // % of rewards to devs
   address public devRewardAddress;         // Dev reward recipient
   address public enokiDaoAgent;            // DAO reward recipient

   // User state
   mapping(address => uint256) public userRewardPerTokenPaid;
   mapping(address => uint256) public rewards;
   uint256 internal _totalSupply;           // Total staked
   mapping(address => uint256) internal _balances;  // User stakes

   // Control
   uint256 public stakingEnabledTime;       // When staking starts
   address public rateVote;                 // Can change reward rate

   /**
    * @dev Initialize pool with core parameters
    * @param _sporeToken SPORE token address
    * @param _stakingToken Token to stake
    * @param _mission Mission contract
    * @param _bannedContractList Security contract
    * @param _devRewardAddress Dev reward recipient
    * @param _enokiDaoAgent DAO reward recipient 
    * @param uintParams [devRewardPercentage, stakingEnabledTime, initialRewardRate]
    */

    function initialize(
        address _sporeToken,
        address _stakingToken,
        address _mission,
        address _bannedContractList,
        address _devRewardAddress,
        address _enokiDaoAgent,
        uint256[3] memory uintParams
    ) public virtual initializer {
        __Context_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __Ownable_init_unchained();

        sporeToken = ISporeToken(_sporeToken);
        stakingToken = IERC20(_stakingToken);

        mission = IMission(_mission);
        bannedContractList = BannedContractList(_bannedContractList);

        /*
            [0] uint256 _devRewardPercentage,
            [1] uint256 stakingEnabledTime_,
            [2] uint256 initialRewardRate_,
        */

        devRewardPercentage = uintParams[0];
        devRewardAddress = _devRewardAddress;

        stakingEnabledTime = uintParams[1];
        sporesPerSecond = uintParams[2];

        enokiDaoAgent = _enokiDaoAgent;

        emit SporeRateChange(sporesPerSecond);
    }

   /* ========== VIEWS ========== */

 function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    // Rewards are turned off at the mission level
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        // Time difference * sporesPerSecond
        return rewardPerTokenStored.add(lastTimeRewardApplicable().sub(lastUpdateTime).mul(sporesPerSecond).mul(1e18).div(_totalSupply));
    }

    /**
    * @dev Calculate rewards earned by account
    */

    function earned(address account) public view returns (uint256) {
        return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

   /* ========== MUTATIVE FUNCTIONS ========== */

   /**
    * @dev Stake tokens to earn rewards
    * @param amount Amount to stake
    * Requirements:
    * - Amount > 0
    * - After stakingEnabledTime
    * - Not paused
    * - Not banned contract
    */
     function stake(uint256 amount) external virtual nonReentrant defend(bannedContractList) whenNotPaused updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        require(now > stakingEnabledTime, "Cannot stake before staking enabled");
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

   /**
    * @dev Withdraw staked tokens (does not harvest rewards)
    */

     // Withdrawing does not harvest, the rewards must be harvested separately
    function withdraw(uint256 amount) public virtual updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

   /**
    * @dev Convert earned SPORE into Mushroom NFTs
    * @param mushroomsToGrow Number of mushrooms to mint
    * Returns dev, dao and remaining rewards
    */

     /// @notice Redeem collected spore for mushrooms. Spore can no longer be withdrawn directly, only redeemed for mushrooms.
    function harvest(uint256 mushroomsToGrow)
        public
        nonReentrant
        updateReward(msg.sender)
        returns (
            uint256 toDev,
            uint256 toDao,
            uint256 remainingReward
        )
    {
        uint256 reward = rewards[msg.sender];

        require(reward > 0, "No harvestable reward");
        require(mushroomsToGrow > 0, "Must harvest at least one mushroom");

        remainingReward = reward;
        toDev = 0;
        toDao = 0;

        // Burn some rewards for mushrooms if desired
        uint256 totalCost = mushroomFactory.costPerMushroom().mul(mushroomsToGrow);

        require(reward >= totalCost, "Not enough rewards to grow the number of mushrooms specified");

        toDev = totalCost.mul(devRewardPercentage).div(MAX_PERCENTAGE);

        if (toDev > 0) {
            mission.sendSpores(devRewardAddress, toDev);
            emit DevRewardPaid(devRewardAddress, toDev);
        }

        toDao = totalCost.sub(toDev);

        mission.sendSpores(enokiDaoAgent, toDao);
        emit DaoRewardPaid(enokiDaoAgent, toDao);

        remainingReward = reward.sub(totalCost);
        mushroomFactory.growMushrooms(msg.sender, mushroomsToGrow);
        emit MushroomsGrown(msg.sender, mushroomsToGrow);

        // Keep any remaining reward in pool
        rewards[msg.sender] = remainingReward;
    }

   /**
    * @dev Emergency withdrawal - forfeit rewards
    */
   function emergencyWithdraw() external nonReentrant {
       withdraw(_balances[msg.sender]);
   }

   /* ========== RESTRICTED FUNCTIONS ========== */

// Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        // Cannot recover the staking token or the rewards token
        require(tokenAddress != address(stakingToken) && tokenAddress != address(sporeToken), "Cannot withdraw the staking or rewards tokens");

        //TODO: Add safeTransfer
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setMushroomFactory(address mushroomFactory_) external onlyOwner {
        mushroomFactory = IMushroomFactory(mushroomFactory_);
    }

    function pauseStaking() external onlyOwner {
        _pause();
    }

    function unpauseStaking() external onlyOwner {
        _unpause();
    }

    function setRateVote(address _rateVote) external onlyOwner {
        rateVote = _rateVote;
    }

    function changeRate(uint256 percentage) external onlyRateVote {
        sporesPerSecond = sporesPerSecond.mul(percentage).div(MAX_PERCENTAGE);
        emit SporeRateChange(sporesPerSecond);
    }

   /* ========== MODIFIERS ========== */

     modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier onlyRateVote() {
        require(msg.sender == rateVote, "onlyRateVote");
        _;
    }

   /* ========== EVENTS ========== */

   event RewardAdded(uint256 reward);
   event Staked(address indexed user, uint256 amount);
   event Withdrawn(address indexed user, uint256 amount);
   event RewardPaid(address indexed user, uint256 reward);
   event DevRewardPaid(address indexed user, uint256 reward);
   event DaoRewardPaid(address indexed user, uint256 reward);
   event MushroomsGrown(address indexed user, uint256 number);
   event Recovered(address token, uint256 amount);
   event SporeRateChange(uint256 newRate);
}