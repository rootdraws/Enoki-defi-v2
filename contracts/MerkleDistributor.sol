// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title ModernMerkleDistributor
 * @notice Advanced token distribution system using Merkle proofs
 * 
 * Key Features:
 * - Efficient airdrop claim mechanism
 * - Flexible claim and tip options
 * - Secure token distribution
 * - Comprehensive access controls
 * 
 * Use Cases:
 * - Community Rewards
 * - Protocol Incentives
 * - NFT Holder Benefits
 * - Growth Initiatives
 */

contract ModernMerkleDistributor is Ownable2Step {
    using SafeERC20 for IERC20;

    // Custom error types for gas-efficient error handling
    error InvalidAddress();
    error ClaimAlreadyProcessed(uint256 index);
    error InvalidClaimProof();
    error InvalidTipPercentage();
    error ReleaseTimeNotReached();
    error ProtectedTokenTransfer();
    error InsufficientBalance();

    // Claim tracking structures
    struct ClaimInfo {
        bool claimed;
        uint256 amount;
    }

    // Core state variables
    IERC20 public immutable distributionToken;
    bytes32 public immutable merkleRoot;
    address public immutable daoTreasury;
    uint256 public immutable daoReleaseTime;

    // Max tip percentage (1%)
    uint256 private constant MAX_TIP_PERCENTAGE = 100; // 1%

    // Claim tracking
    mapping(uint256 => ClaimInfo) private _claims;

    // Events with enhanced information
    event TokensClaimed(
        uint256 indexed index, 
        address indexed recipient, 
        uint256 claimedAmount, 
        uint256 tipAmount
    );
    event UnclaimedTokensTransferred(
        address indexed recipient, 
        uint256 amount
    );
    event DustCollected(
        address indexed collector, 
        address indexed token, 
        uint256 amount
    );

    /**
     * @notice Constructor initializes the distributor
     * @param _token Distribution token
     * @param _merkleRoot Merkle tree root for claims
     * @param _daoTreasury DAO treasury address
     * @param _daoReleaseTime Time when unclaimed tokens can be transferred
     */
    constructor(
        IERC20 _token,
        bytes32 _merkleRoot,
        address _daoTreasury,
        uint256 _daoReleaseTime
    ) {
        if (address(_token) == address(0)) revert InvalidAddress();
        if (_daoTreasury == address(0)) revert InvalidAddress();
        if (_daoReleaseTime <= block.timestamp) revert ReleaseTimeNotReached();

        distributionToken = _token;
        merkleRoot = _merkleRoot;
        daoTreasury = _daoTreasury;
        daoReleaseTime = _daoReleaseTime;
    }

    /**
     * @notice Check if a specific claim has been processed
     * @param index Claim index
     * @return Whether the claim has been processed
     */
    function isClaimed(uint256 index) public view returns (bool) {
        return _claims[index].claimed;
    }

    /**
     * @notice Process a token claim with optional tip
     * @param index Unique claim index
     * @param recipient Token recipient
     * @param amount Total claimable amount
     * @param merkleProof Merkle proof validating the claim
     * @param tipPercentage Tip percentage in basis points
     */
    function claim(
        uint256 index,
        address recipient,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint256 tipPercentage
    ) external {
        // Validate inputs
        if (tipPercentage > MAX_TIP_PERCENTAGE) revert InvalidTipPercentage();
        if (isClaimed(index)) revert ClaimAlreadyProcessed(index);

        // Verify merkle proof
        bytes32 node = keccak256(abi.encodePacked(index, recipient, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) {
            revert InvalidClaimProof();
        }

        // Mark as claimed
        _claims[index] = ClaimInfo(true, amount);

        // Calculate tip
        uint256 tip = msg.sender == recipient 
            ? (amount * tipPercentage) / 10_000 
            : 0;
        uint256 claimAmount = amount - tip;

        // Transfer tokens
        distributionToken.safeTransfer(recipient, claimAmount);
        if (tip > 0) {
            distributionToken.safeTransfer(owner(), tip);
        }

        emit TokensClaimed(index, recipient, claimAmount, tip);
    }

    /**
     * @notice Transfer unclaimed tokens to DAO after release time
     */
    function transferUnclaimedToDao() external {
        if (block.timestamp < daoReleaseTime) revert ReleaseTimeNotReached();

        uint256 remainingBalance = distributionToken.balanceOf(address(this));
        if (remainingBalance == 0) revert InsufficientBalance();

        distributionToken.safeTransfer(daoTreasury, remainingBalance);

        emit UnclaimedTokensTransferred(daoTreasury, remainingBalance);
    }

    /**
     * @notice Collect tokens accidentally sent to contract
     * @param tokenAddress Token to collect (address(0) for ETH)
     * @param amount Amount to collect
     */
    function collectDust(
        address tokenAddress, 
        uint256 amount
    ) external onlyOwner {
        // Prevent collecting the distribution token
        if (tokenAddress == address(distributionToken)) {
            revert ProtectedTokenTransfer();
        }

        // Collect tokens or ETH
        if (tokenAddress == address(0)) {
            // Collect ETH
            (bool success, ) = payable(owner()).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            // Collect ERC20 tokens
            IERC20(tokenAddress).safeTransfer(owner(), amount);
        }

        emit DustCollected(msg.sender, tokenAddress, amount);
    }

    /**
     * @notice Get available token balance
     * @return Current balance of distribution tokens
     */
    function availableTokenBalance() external view returns (uint256) {
        return distributionToken.balanceOf(address(this));
    }

    /**
     * @notice Allow contract to receive ETH
     */
    receive() external payable {}
}