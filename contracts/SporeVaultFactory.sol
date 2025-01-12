import "../frontend/SporeQuests.sol";

// File Processed by Claude.AI Sonnet on 1/11/25.

// SPORE VAULT FACTORY CONTRACT
// This is a factory contract for the Spore ecosystem. It is used to deploy vaults.

contract SporeVaultFactory is Ownable {
    SporeQuests public quests;
    string public constant DEFAULT_DESCRIPTION = "Join this mission to earn SPORE rewards by providing liquidity to our strategy.";

    // Set the quests contract
    function setQuestsContract(address _quests) external onlyOwner {
        if (_quests == address(0)) revert InvalidAddress();
        quests = SporeQuests(_quests);
    }

// Deploy a new vault
    function deployVault(
        address strategy,
        string calldata strategyName,
        address daoRewardAddress,
        uint256 rewardRate,
        IERC20 depositToken
    ) external onlyOwner returns (address vault, address vesting) {
        if (strategy == address(0)) revert InvalidAddress();
        if (daoRewardAddress == address(0)) revert InvalidAddress();
        
        // Deploy new vault and vesting contracts
        vault = address(new SporeVault(
            strategy,
            address(depositToken),
            daoRewardAddress,
            rewardRate
        ));
        
        vesting = address(new SporeVesting(
            vault,
            address(depositToken)
        ));
        
        // Initialize vault with vesting contract
        SporeVault(vault).setVestingContract(vesting);
        
        // Register as new mission if quests contract is set
        if (address(quests) != address(0)) {
            quests.registerMission(
                vault,
                vesting,
                strategy,
                strategyName,
                DEFAULT_DESCRIPTION
            );
        }

        emit VaultDeployed(strategy, vault, vesting, address(depositToken));
    }
} 