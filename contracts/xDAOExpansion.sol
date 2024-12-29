// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title EnokiDAO
 * @notice Decentralized governance contract for ENOKI ecosystem
 * @dev Coordinates key ecosystem activities through proposable actions
 */
interface IEnokiDAO {
    /**
     * @notice Propose a new NFT series launch
     * @dev Allows DAO members to suggest new artistic series
     * @param name Descriptive name of the proposed series
     * @param community Address representing the target community
     * @param artist Wallet address of the proposed artist
     * @param maxSupply Maximum number of NFTs in the series
     */
    function proposeSeries(
        string memory name,
        address community,
        address artist,
        uint256 maxSupply
    ) external;
    
    /**
     * @notice Propose a new CORN (Community Operational Resource Narrative) strategy
     * @dev Allows allocation of resources across specified targets
     * @param targets Addresses of contracts or wallets to receive funds
     * @param amounts Corresponding funding amounts for each target
     */
    function proposeVoteStrategy(
        address[] memory targets,
        uint256[] memory amounts
    ) external;

    /**
     * @notice Propose hiring an artist or creative for a marketing campaign
     * @dev Allows community to select and fund creative initiatives
     * @param artist Wallet address of the proposed artist/creative
     * @param campaignBudget Total budget for the marketing campaign
     * @param campaignDescription Detailed description of proposed campaign
     */
    function proposeMarketingCampaign(
        address artist,
        uint256 campaignBudget,
        string memory campaignDescription
    ) external;

    /**
     * @notice Propose partnership with another creative community or platform
     * @dev Enables expansion and collaboration opportunities
     * @param partnerAddress Address of the potential partner
     * @param collaborationType Type of proposed collaboration
     * @param potentialBenefits Description of expected partnership benefits
     */
    function proposePartnership(
        address partnerAddress,
        string memory collaborationType,
        string memory potentialBenefits
    ) external;
}

/**
 * @title EnokiDAOExecutor
 * @notice Base contract for executable DAO proposals
 * @dev Provides a standard interface for actions the DAO can execute
 */
abstract contract EnokiDAOExecutor {
    /**
     * @notice Execute a specific action approved by DAO voting
     * @dev To be implemented by specific execution contracts
     */
    function executeAction() public virtual;
}

/**
 * @title ArtistHiringProposal
 * @notice Example of a specific executable proposal for hiring an artist
 */
contract ArtistHiringProposal is EnokiDAOExecutor {
    address public artist;
    uint256 public campaignBudget;
    string public campaignDescription;

    constructor(
        address _artist, 
        uint256 _campaignBudget, 
        string memory _campaignDescription
    ) {
        artist = _artist;
        campaignBudget = _campaignBudget;
        campaignDescription = _campaignDescription;
    }

    function executeAction() public override {
        // Implementation of artist hiring logic
        // Could include:
        // - Transfer funds
        // - Trigger contract interactions
        // - Emit events
    }
}