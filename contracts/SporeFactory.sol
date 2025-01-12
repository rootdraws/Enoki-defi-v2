import "./SporeMissions.sol";

// File Processed by Claude.AI Sonnet on 1/11/25.

// SPORE FACTORY CONTRACT
// This is a factory contract for the Spore ecosystem. It is used to deploy vaults.

contract SporeFactory is Ownable {
    event VaultDeployed(
        address indexed strategy,
        address indexed vault,
        address indexed vesting,
        address depositToken
    );

    SporeMissions public missions;
    string public constant DEFAULT_DESCRIPTION = "Join this mission to earn SPORE and Farm Enoki!";

    // Set the missions contract
    function setMissionsContract(address _missions) external onlyOwner {
        if (_missions == address(0)) revert InvalidAddress();
        missions = SporeMissions(_missions);
    }

// Deploy a new mission
    function deployMission(
        address strategy,
        string calldata strategyName,
        address daoRewardAddress,
        uint256 rewardRate,
        IERC20 depositToken
    ) external onlyOwner returns (address vault, address vesting) {
        if (strategy == address(0)) revert InvalidAddress();
        if (daoRewardAddress == address(0)) revert InvalidAddress();
        
        // Deploy new mission and vesting contracts
        mission = address(new SporeMission(
            strategy,
            address(depositToken),
            daoRewardAddress,
            rewardRate
        ));
        
        vesting = address(new SporeVesting(
            mission,
            address(depositToken)
        ));
        
        // Initialize mission with vesting contract
        SporeMission(mission).setVestingContract(vesting);
        
        // Register as new mission if quests contract is set
        if (address(missions) != address(0)) {
            missions.registerMission(
                mission,
                vesting,
                strategy,
                strategyName,
                DEFAULT_DESCRIPTION
            );
        }

        emit MissionDeployed(strategy, mission, vesting, address(depositToken));
    }
} 