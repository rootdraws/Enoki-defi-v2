import "../frontend/SporeQuests.sol";

contract SporeVaultFactory is Ownable {
    SporeQuests public quests;
    string public constant DEFAULT_DESCRIPTION = "Join this mission to earn SPORE rewards by providing liquidity to our strategy.";

    function setQuestsContract(address _quests) external onlyOwner {
        if (_quests == address(0)) revert InvalidAddress();
        quests = SporeQuests(_quests);
    }

    function deployVault(
        address strategy,
        string calldata strategyName,
        address daoRewardAddress,
        uint256 rewardRate,
        IERC20 depositToken
    ) external onlyOwner returns (address vault, address vesting) {
        // ... existing deployment code ...

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