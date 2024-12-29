// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Mission
 * @notice Controls SPORE token distribution to approved pools
 * @dev Manages core economic system for SPORE reward distribution
 * 
 * Key Features:
 * - Holds SPORE tokens for distribution
 * - Only approved pools can request SPORE transfers
 * - Owner can manage pool approval status
 */
contract Mission is Ownable {
    using SafeERC20 for IERC20;

    // Core token and approval state
    IERC20 public immutable sporeToken;
    mapping(address => bool) private _approvedPools;

    // Events
    event PoolApproved(address indexed pool);
    event PoolRevoked(address indexed pool);
    event SporesHarvested(address indexed pool, uint256 amount);

    /**
     * @notice Constructor sets up the Mission contract
     * @param _sporeToken Address of the SPORE token contract
     */
    constructor(IERC20 _sporeToken) Ownable(msg.sender) {
        require(address(_sporeToken) != address(0), "Invalid SPORE token");
        sporeToken = _sporeToken;
    }

    /**
     * @notice Check if a pool is approved
     * @param pool Address of the pool to check
     * @return Whether the pool is approved
     */
    function isPoolApproved(address pool) external view returns (bool) {
        return _approvedPools[pool];
    }

    /**
     * @notice Allows approved pools to request SPORE transfers
     * @param recipient Address to receive SPORE tokens
     * @param amount Amount of SPORE to transfer
     */
    function sendSpores(address recipient, uint256 amount) external {
        require(_approvedPools[msg.sender], "Only approved pools");
        require(recipient != address(0), "Invalid recipient");
        
        sporeToken.safeTransfer(recipient, amount);
        emit SporesHarvested(msg.sender, amount);
    }

    /**
     * @notice Owner can approve pools to request SPORE
     * @param pool Address of pool to approve
     */
    function approvePool(address pool) external onlyOwner {
        require(pool != address(0), "Invalid pool address");
        require(!_approvedPools[pool], "Pool already approved");
        
        _approvedPools[pool] = true;
        emit PoolApproved(pool);
    }

    /**
     * @notice Owner can revoke pool approval
     * @param pool Address of pool to revoke
     */
    function revokePool(address pool) external onlyOwner {
        require(_approvedPools[pool], "Pool not previously approved");
        
        _approvedPools[pool] = false;
        emit PoolRevoked(pool);
    }

    /**
     * @notice Retrieve the contract's SPORE token balance
     * @return Current SPORE token balance
     */
    function getSporeBalance() external view returns (uint256) {
        return sporeToken.balanceOf(address(this));
    }
}