// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title GeyserEscrow
 * @notice Manages locking of tokens into the geyser reward system
 * @dev Supports token locking with potential for multi-token expansion
 * 
 * Token Flow:
 * ETH Staking → Earn SPORE → Mint Mushrooms → Stake in Geyser → Earn ENOKI
 */
contract GeyserEscrow is Ownable {
    using SafeERC20 for IERC20;

    // Interface for geyser interaction
    interface IEnokiGeyser {
        function getDistributionToken() external view returns (IERC20);
        function lockTokens(uint256 amount, uint256 durationSec) external;
    }

    // Reference to main geyser contract
    IEnokiGeyser public immutable geyser;

    // Potential multi-token support (commented out)
    mapping(address => bool) private _allowedRewardTokens;

    // Events
    event TokensLocked(uint256 amount, uint256 duration);
    event RewardTokenAdded(address indexed token);
    event RewardTokenRemoved(address indexed token);

    /**
     * @notice Constructor sets up the geyser reference
     * @param _geyser Address of the geyser contract
     */
    constructor(IEnokiGeyser _geyser) Ownable(msg.sender) {
        geyser = _geyser;
        
        // Optionally add initial distribution token
        address initialToken = address(geyser.getDistributionToken());
        _allowedRewardTokens[initialToken] = true;
    }

    /**
     * @notice Add a new reward token to allowed list
     * @param tokenAddress Address of the token to allow
     */
    function addRewardToken(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        _allowedRewardTokens[tokenAddress] = true;
        emit RewardTokenAdded(tokenAddress);
    }

    /**
     * @notice Remove a reward token from allowed list
     * @param tokenAddress Address of the token to disallow
     */
    function removeRewardToken(address tokenAddress) external onlyOwner {
        _allowedRewardTokens[tokenAddress] = false;
        emit RewardTokenRemoved(tokenAddress);
    }

    /**
     * @notice Check if a token is allowed
     * @param tokenAddress Token to check
     * @return Whether the token is allowed
     */
    function isRewardTokenAllowed(address tokenAddress) external view returns (bool) {
        return _allowedRewardTokens[tokenAddress];
    }

    /**
     * @notice Lock tokens into the geyser
     * @param amount Amount of tokens to lock
     * @param durationSec Duration tokens are locked for
     */
    function lockTokens(
        uint256 amount,
        uint256 durationSec
    ) external onlyOwner {
        // Get distribution token from geyser
        IERC20 distributionToken = geyser.getDistributionToken();
        
        // Validate token (if multi-token support is desired)
        require(
            _allowedRewardTokens[address(distributionToken)], 
            "Token not allowed"
        );

        // Approve and lock tokens
        distributionToken.safeApprove(address(geyser), amount);
        geyser.lockTokens(amount, durationSec);

        emit TokensLocked(amount, durationSec);
    }

    /**
     * @notice Retrieve the current distribution token
     * @return Address of the distribution token
     */
    function getDistributionToken() external view returns (address) {
        return address(geyser.getDistributionToken());
    }
}