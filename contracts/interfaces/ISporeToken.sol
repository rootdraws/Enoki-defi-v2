// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// File Modernized by Claude.AI Sonnet on 12/29/24.

/**
* @title ISporeToken
* @notice Interface for a fungible token with minting, burning and transfer controls
* @dev Extends standard ERC20 with additional governance features
*/
interface ISporeToken {
   /**
    * @notice Standard ERC20 transfer event
    * @param from Address tokens transferred from 
    * @param to Address tokens transferred to
    * @param value Amount of tokens transferred
    */
   event Transfer(
       address indexed from,
       address indexed to, 
       uint256 value
   );

   /**
    * @notice Standard ERC20 approval event
    * @param owner Address granting approval
    * @param spender Address receiving approval
    * @param value Amount of tokens approved
    */
   event Approval(
       address indexed owner,
       address indexed spender,
       uint256 value
   );

   /**
    * @notice Emitted when tokens are burned
    * @param from Address tokens burned from
    * @param amount Amount of tokens burned
    */
   event Burn(
       address indexed from,
       uint256 amount
   );

   /**
    * @notice Emitted when tokens are minted
    * @param to Address tokens minted to
    * @param amount Amount of tokens minted
    */
   event Mint(
       address indexed to,
       uint256 amount
   );

   /**
    * @notice Emitted when an account receives initial liquidity transfer rights
    * @param account Address granted rights
    */
   event InitialLiquidityTransferRightsAdded(
       address indexed account
   );

   /**
    * @notice Emitted when transfers are enabled globally
    */
   event TransfersEnabled();

   /**
    * @notice Emitted when a minter role is granted
    * @param account Address granted minting rights
    * @param grantedBy Address that granted the rights
    */
   event MinterAdded(
       address indexed account,
       address indexed grantedBy
   );

   /**
    * @notice Emitted when a minter role is revoked
    * @param account Address rights revoked from
    * @param revokedBy Address that revoked the rights
    */
   event MinterRemoved(
       address indexed account,
       address indexed revokedBy
   );

   /**
    * @notice Error thrown when transfer amount exceeds balance
    * @param from Address attempting transfer
    * @param amount Amount attempted
    * @param balance Actual balance
    */
   error InsufficientBalance(address from, uint256 amount, uint256 balance);

   /**
    * @notice Error thrown when transfer amount exceeds allowance
    * @param spender Address attempting transfer
    * @param amount Amount attempted
    * @param allowance Actual allowance
    */
   error InsufficientAllowance(address spender, uint256 amount, uint256 allowance);

   /**
    * @notice Error thrown when transfers are not yet enabled
    */
   error TransfersNotEnabled();

   /**
    * @notice Error thrown when caller lacks minter role
    * @param caller Address attempting mint
    */
   error NotMinter(address caller);

   /**
    * @notice Error thrown when account already has minter role
    * @param account Address already granted role
    */
   error AlreadyMinter(address account);

   /* ========== STANDARD ERC20 ========== */

   function totalSupply() external view returns (uint256);
   
   function balanceOf(
       address account
   ) external view returns (uint256);

   function transfer(
       address recipient,
       uint256 amount
   ) external returns (bool);

   function allowance(
       address owner,
       address spender
   ) external view returns (uint256);

   function approve(
       address spender,
       uint256 amount
   ) external returns (bool);

   function transferFrom(
       address sender,
       address recipient,
       uint256 amount
   ) external returns (bool);

   /* ========== EXTENSIONS ========== */

   /**
    * @notice Burns tokens from caller's balance
    * @param amount Amount to burn
    */
   function burn(uint256 amount) external;

   /**
    * @notice Mints new tokens to specified address
    * @param to Address to mint to
    * @param amount Amount to mint
    * @dev Only callable by accounts with minter role
    */
   function mint(
       address to,
       uint256 amount
   ) external;

   /**
    * @notice Grants initial liquidity transfer rights to an account
    * @param account Address to grant rights to
    * @dev Only callable by contract owner
    */
   function addInitialLiquidityTransferRights(
       address account
   ) external;

   /**
    * @notice Enables transfers globally
    * @dev Only callable by contract owner
    */
   function enableTransfers() external;

   /**
    * @notice Grants minter role to an account
    * @param account Address to grant role to
    * @dev Only callable by contract owner
    */
   function addMinter(address account) external;

   /**
    * @notice Revokes minter role from an account
    * @param account Address to revoke role from
    * @dev Only callable by contract owner
    */
   function removeMinter(address account) external;

   /**
    * @notice Returns true if transfers are enabled
    */
   function transfersEnabled() external view returns (bool);

   /**
    * @notice Returns true if account has minter role
    * @param account Address to check
    */
   function isMinter(address account) external view returns (bool);
}