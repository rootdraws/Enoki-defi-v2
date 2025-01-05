// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title ModernMerkleDistributor
 * @notice Advanced token distribution system using Merkle proofs with enhanced security
 * @dev Implements ReentrancyGuard and Pausable for additional safety
 */

contract ModernMerkleDistributor is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Custom errors with descriptive parameters
    error InvalidAddress(address providedAddress);
    error ClaimAlreadyProcessed(uint256 index, address claimer);
    error InvalidClaimProof(uint256 index, address recipient, uint256 amount);
    error InvalidTipPercentage(uint256 provided, uint256 maximum);
    error ReleaseTimeNotReached(uint256 current, uint256 required);
    error ProtectedTokenTransfer(address token);
    error InsufficientBalance(uint256 requested, uint256 available);
    error ZeroAmount();
    error InvalidMerkleRoot();

    // Claim tracking with expanded information
    struct ClaimInfo {
        bool claimed;
        uint256 amount;
        uint256 timestamp;
        address claimer;
    }

    // Core state variables
    IERC20 public immutable distributionToken;
    bytes32 public immutable merkleRoot;
    address public immutable daoTreasury;
    uint256 public immutable daoReleaseTime;

    // Constants
    uint256 private constant MAX_TIP_PERCENTAGE = 100; // 1% = 100 basis points
    uint256 private constant BASIS_POINTS = 10000;

    // Claim tracking
    mapping(uint256 index => ClaimInfo info) private _claims;
    uint256 public totalClaimed;
    uint256 public totalClaims;

    // Events with comprehensive information
    event TokensClaimed(
        uint256 indexed index,
        address indexed recipient,
        address indexed claimer,
        uint256 claimedAmount,
        uint256 tipAmount,
        uint256 timestamp
    );
    event UnclaimedTokensTransferred(
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );
    event DustCollected(
        address indexed collector,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );
    event EmergencyAction(
        string indexed action,
        address indexed initiator,
        uint256 timestamp
    );

    /**
     * @notice Constructor initializes the distributor with safety checks
     * @param _token Distribution token address
     * @param _merkleRoot Merkle tree root for claim verification
     * @param _daoTreasury DAO treasury address for unclaimed tokens
     * @param _daoReleaseTime Time when unclaimed tokens can be transferred
     */
    constructor(
        IERC20 _token,
        bytes32 _merkleRoot,
        address _daoTreasury,
        uint256 _daoReleaseTime
    ) Ownable(msg.sender) {
        if (address(_token) == address(0)) revert InvalidAddress(address(0));
        if (_daoTreasury == address(0)) revert InvalidAddress(_daoTreasury);
        if (_merkleRoot == bytes32(0)) revert InvalidMerkleRoot();
        if (_daoReleaseTime <= block.timestamp) {
            revert ReleaseTimeNotReached(block.timestamp, _daoReleaseTime);
        }

        distributionToken = _token;
        merkleRoot = _merkleRoot;
        daoTreasury = _daoTreasury;
        daoReleaseTime = _daoReleaseTime;
    }

    /**
     * @notice Get claim information
     * @param index Claim index to check
     * @return claimed Whether the claim was processed
     * @return amount Amount of the claim
     * @return timestamp When the claim was processed
     * @return claimer Address that processed the claim
     */
    function getClaimInfo(uint256 index) external view returns (
        bool claimed,
        uint256 amount,
        uint256 timestamp,
        address claimer
    ) {
        ClaimInfo memory info = _claims[index];
        return (info.claimed, info.amount, info.timestamp, info.claimer);
    }

    /**
     * @notice Check if a specific claim has been processed
     * @param index Claim index to verify
     * @return claimed Status of the claim
     */
    function isClaimed(uint256 index) public view returns (bool claimed) {
        return _claims[index].claimed;
    }

    /**
     * @notice Process a token claim with optional tip
     * @param index Unique claim index
     * @param recipient Token recipient address
     * @param amount Total claimable amount
     * @param merkleProof Merkle proof validating the claim
     * @param tipPercentage Optional tip percentage in basis points
     */
    function claim(
        uint256 index,
        address recipient,
        uint256 amount,
        bytes32[] calldata merkleProof,
        uint256 tipPercentage
    ) external nonReentrant whenNotPaused {
        if (recipient == address(0)) revert InvalidAddress(recipient);
        if (amount == 0) revert ZeroAmount();
        if (tipPercentage > MAX_TIP_PERCENTAGE) {
            revert InvalidTipPercentage(tipPercentage, MAX_TIP_PERCENTAGE);
        }
        if (isClaimed(index)) revert ClaimAlreadyProcessed(index, msg.sender);

        // Verify merkle proof
        bytes32 node = keccak256(abi.encodePacked(index, recipient, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) {
            revert InvalidClaimProof(index, recipient, amount);
        }

        // Update state before transfers
        _claims[index] = ClaimInfo({
            claimed: true,
            amount: amount,
            timestamp: block.timestamp,
            claimer: msg.sender
        });

        unchecked {
            // Safe because these values cannot practically overflow
            totalClaimed += amount;
            totalClaims++;
        }

        // Calculate tip if applicable
        uint256 tip = msg.sender == recipient 
            ? (amount * tipPercentage) / BASIS_POINTS 
            : 0;
        uint256 claimAmount = amount - tip;

        // Perform transfers
        distributionToken.safeTransfer(recipient, claimAmount);
        if (tip > 0) {
            distributionToken.safeTransfer(owner(), tip);
        }

        emit TokensClaimed(
            index,
            recipient,
            msg.sender,
            claimAmount,
            tip,
            block.timestamp
        );
    }

    /**
     * @notice Transfer unclaimed tokens to DAO after release time
     */
    function transferUnclaimedToDao() external nonReentrant {
        if (block.timestamp < daoReleaseTime) {
            revert ReleaseTimeNotReached(block.timestamp, daoReleaseTime);
        }

        uint256 remainingBalance = distributionToken.balanceOf(address(this));
        if (remainingBalance == 0) revert InsufficientBalance(0, remainingBalance);

        distributionToken.safeTransfer(daoTreasury, remainingBalance);

        emit UnclaimedTokensTransferred(
            daoTreasury,
            remainingBalance,
            block.timestamp
        );
    }

    /**
     * @notice Emergency pause functionality
     */
    function pause() external onlyOwner {
        _pause();
        emit EmergencyAction("PAUSE", msg.sender, block.timestamp);
    }

    /**
     * @notice Resume operations after pause
     */
    function unpause() external onlyOwner {
        _unpause();
        emit EmergencyAction("UNPAUSE", msg.sender, block.timestamp);
    }

    /**
     * @notice Collect accidentally sent tokens
     * @param tokenAddress Token to collect (address(0) for ETH)
     * @param amount Amount to collect
     */
    function collectDust(
        address tokenAddress,
        uint256 amount
    ) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();
        
        if (tokenAddress == address(distributionToken)) {
            revert ProtectedTokenTransfer(tokenAddress);
        }

        if (tokenAddress == address(0)) {
            uint256 balance = address(this).balance;
            if (amount > balance) {
                revert InsufficientBalance(amount, balance);
            }
            (bool success, ) = payable(owner()).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            IERC20 token = IERC20(tokenAddress);
            uint256 balance = token.balanceOf(address(this));
            if (amount > balance) {
                revert InsufficientBalance(amount, balance);
            }
            token.safeTransfer(owner(), amount);
        }

        emit DustCollected(msg.sender, tokenAddress, amount, block.timestamp);
    }

    /**
     * @notice Get contract balances
     */
    function getDistributionTokenBalance() external view returns (uint256) {
        return distributionToken.balanceOf(address(this));
    }

    function getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Allow contract to receive ETH
     */
    receive() external payable {}
}