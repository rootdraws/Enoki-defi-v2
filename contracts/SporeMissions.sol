// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../vaults/SporeVault.sol";
import "../vaults/SporeVaultFactory.sol";

// SPORE Missions Contract
// This is a contract for the Spore ecosystem. It is used to create missions for the vaults.

contract SporeMissions is Ownable {
    using SafeERC20 for IERC20;

    struct Mission {
        address vault;      
        address vesting;    
        address strategy;   
        string name;        
        string description; 
        uint256 tvl;       
        uint256 apy;       
        bool active;       
    }

    // State variables
    mapping(uint256 => Mission) public missions;
    uint256 public missionCount;
    SporeVaultFactory public immutable factory;

    // Events
    event MissionCreated(uint256 indexed missionId, string name, address vault);
    event MissionUpdated(uint256 indexed missionId, uint256 tvl, uint256 apy);
    event MissionCompleted(uint256 indexed missionId);

    error NotFactory();
    error MissionNotActive();
    error InvalidMissionId();

    constructor(SporeVaultFactory _factory) Ownable(msg.sender) {
        factory = _factory;
    }

    function registerMission(
        address vault,
        address vesting,
        address strategy,
        string calldata name,
        string calldata description
    ) external returns (uint256 missionId) {
        if (msg.sender != address(factory)) revert NotFactory();
        
        missionId = missionCount++;
        missions[missionId] = Mission({
            vault: vault,
            vesting: vesting,
            strategy: strategy,
            name: name,
            description: description,
            tvl: 0,
            apy: 0,
            active: true
        });

        emit MissionCreated(missionId, name, vault);
    }

    function getActiveMissions() external view returns (uint256[] memory) {
        uint256[] memory activeMissionIds = new uint256[](missionCount);
        uint256 activeCount = 0;
        
        for (uint256 i = 0; i < missionCount; i++) {
            if (missions[i].active) {
                activeMissionIds[activeCount] = i;
                activeCount++;
            }
        }

        // Resize array to actual count
        assembly {
            mstore(activeMissionIds, activeCount)
        }
        
        return activeMissionIds;
    }

    function getMissionDetails(uint256 missionId) external view returns (
        address vault,
        address vesting,
        string memory name,
        string memory description,
        uint256 tvl,
        uint256 apy
    ) {
        Mission memory m = missions[missionId];
        if (!m.active) revert MissionNotActive();
        return (m.vault, m.vesting, m.name, m.description, m.tvl, m.apy);
    }

    function joinMission(uint256 missionId, uint256 amount) external {
        Mission memory m = missions[missionId];
        if (!m.active) revert MissionNotActive();
        
        SporeVault(m.vault).deposit(amount, msg.sender);
    }

    function completeMission(uint256 missionId) external {
        Mission memory m = missions[missionId];
        if (!m.active) revert MissionNotActive();
        
        uint256 shares = SporeVault(m.vault).balanceOf(msg.sender);
        SporeVault(m.vault).withdraw(shares, msg.sender, msg.sender);
    }

    function updateMissionStats(
        uint256 missionId,
        uint256 newTvl,
        uint256 newApy
    ) external onlyOwner {
        if (missionId >= missionCount) revert InvalidMissionId();
        
        Mission storage m = missions[missionId];
        m.tvl = newTvl;
        m.apy = newApy;

        emit MissionUpdated(missionId, newTvl, newApy);
    }
} 