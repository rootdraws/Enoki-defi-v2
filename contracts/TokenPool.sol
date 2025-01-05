// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// File Modernized by Claude.AI Sonnet on 1/5/25.

/**
 * @title TokenPool
 * @dev Modern contract to manage isolated token pools with enhanced security
 * 
 * Key Features:
 * - Isolated token pools with SafeERC20 protection
 * - Owner-controlled transfers with reentrancy protection
 * - Emergency rescue function for wrong tokens
 * - Upgradeable pattern with modern OpenZeppelin contracts
 * - Gas optimized operations
 * - Enhanced security features
 */

contract TokenPool is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    using SafeERC20 for IERC20;
    // Is Upgradeable, but Openzeppelin says that they are the same, execpt for naming convention. 
    // https://forum.openzeppelin.com/t/safeerc20-vs-safeerc20upgradeable/17326

    /// @dev Main token being pooled
    IERC20 public token;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // Custom errors for gas optimization
    error CannotRescuePoolToken();
    error ZeroAddress();
    error ZeroAmount();

    // Events
    event TokensTransferred(address indexed to, uint256 amount);
    event TokensRescued(address indexed token, address indexed to, uint256 amount);

    /**
     * @dev Initializes pool with specific token
     * @param _token Address of the token to be pooled
     */
    function initialize(IERC20 _token) public initializer {
        if (address(_token) == address(0)) revert ZeroAddress();
        
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        
        token = _token;
    }

    /**
     * @dev Get current token balance of this specific pool
     * @return uint256 Current balance of pooled tokens
     */
    function balance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @dev Owner can transfer tokens from this specific pool
     * @param to Recipient address
     * @param amount Amount to transfer from this pool
     */
    function transfer(
        address to, 
        uint256 amount
    ) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        token.safeTransfer(to, amount);
        emit TokensTransferred(to, amount);
    }

    /**
     * @dev Emergency function to rescue wrong tokens sent to this pool
     * @param tokenToRescue Address of token to rescue
     * @param to Recipient of rescued tokens
     * @param amount Amount to rescue
     */
    function rescueFunds(
        IERC20 tokenToRescue,
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant {
        if (address(tokenToRescue) == address(token)) {
            revert CannotRescuePoolToken();
        }
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        tokenToRescue.safeTransfer(to, amount);
        emit TokensRescued(address(tokenToRescue), to, amount);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}