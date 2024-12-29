// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title TokenVesting
* @dev Contract that handles token vesting with cliff periods and linear release
* 
* Key Features:
* - Linear vesting over time
* - Cliff period before vesting starts
* - Revocable by owner (optional)
* - Supports any ERC20 token
* 
* Vesting Schedule Example:
* 1. Token grant of 4000 tokens over 4 years with 1 year cliff:
*    - Nothing for first year (cliff)
*    - After cliff: ~83.33 tokens released per month
*    - At 4 years: All 4000 tokens released
*
* Common Use Cases:
* - Team token vesting
* - Advisor token grants
* - Investor unlocks
* - Employee compensation
*
* Adding New Token to Vest:
* 1. Transfer tokens to vesting contract address
* 2. Token will automatically be tracked via mappings
* 3. Example:
*    MyToken.transfer(vestingContract.address, amount);
*    // Token now vests according to schedule
*    // Can check progress: vestingContract.vestedAmount(MyToken.address)
*    // Can release: vestingContract.release(MyToken.address)
*/

// You can also probably use an Openzeppelin Vesting Contract
// @openzeppelin/contracts/finance/VestingWallet.sol

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract TokenVesting is Ownable {
   using SafeERC20 for IERC20;

   // Events to track releases and revocations
   event TokensReleased(address token, uint256 amount);
   event TokenVestingRevoked(address token);

   // Core vesting parameters
   address private _beneficiary;           // Who receives the tokens
   uint256 private _cliff;                 // When tokens start vesting
   uint256 private _start;                 // Start of vesting period
   uint256 private _duration;              // How long vesting lasts
   bool private _revocable;                // Can owner revoke?

   // Tracking for multiple tokens - any ERC20 can be added
   mapping (address => uint256) private _released;    // Amount released per token
   mapping (address => bool) private _revoked;        // Revocation status per token

   /**
    * @dev Sets up vesting schedule
    * Schedule applies to any token added to contract
    * @param beneficiary Who receives the tokens
    * @param cliffDuration How long until first tokens vest
    * @param start When vesting starts
    * @param duration Total vesting period
    * @param revocable Can owner revoke unvested tokens
    */
   constructor (address beneficiary, uint256 start, uint256 cliffDuration, uint256 duration, bool revocable) public {
       require(beneficiary != address(0), "TokenVesting: beneficiary is the zero address");
       require(cliffDuration <= duration, "TokenVesting: cliff is longer than duration");
       require(duration > 0, "TokenVesting: duration is 0");
       require(start.add(duration) > block.timestamp, "TokenVesting: final time is before current time");

       _beneficiary = beneficiary;
       _revocable = revocable;
       _duration = duration;
       _cliff = start.add(cliffDuration);
       _start = start;
   }

   // Getter functions for vesting parameters
   function beneficiary() public view returns (address) {
       return _beneficiary;
   }

   function cliff() public view returns (uint256) {
       return _cliff;
   }

   function start() public view returns (uint256) {
       return _start;
   }

   function duration() public view returns (uint256) {
       return _duration;
   }

   function revocable() public view returns (bool) {
       return _revocable;
   }

   function released(address token) public view returns (uint256) {
       return _released[token];
   }

   function revoked(address token) public view returns (bool) {
       return _revoked[token];
   }

   /**
    * @notice Transfers vested tokens to beneficiary
    * Can be called for any token held by contract
    * @param token ERC20 token which is being vested
    */
   function release(IERC20 token) public {
       uint256 unreleased = _releasableAmount(token);

       require(unreleased > 0, "TokenVesting: no tokens are due");

       _released[address(token)] = _released[address(token)].add(unreleased);

       token.safeTransfer(_beneficiary, unreleased);

       emit TokensReleased(address(token), unreleased);
   }

   /**
    * @notice Allows the owner to revoke the vesting
    * Only impacts unvested tokens
    * @param token ERC20 token which is being vested
    */
   function revoke(IERC20 token) public onlyOwner {
       require(_revocable, "TokenVesting: cannot revoke");
       require(!_revoked[address(token)], "TokenVesting: token already revoked");

       uint256 balance = token.balanceOf(address(this));

       uint256 unreleased = _releasableAmount(token);
       uint256 refund = balance.sub(unreleased);

       _revoked[address(token)] = true;

       token.safeTransfer(owner(), refund);

       emit TokenVestingRevoked(address(token));
   }

   /**
    * @dev Calculates releasable but unvested tokens
    */
   function _releasableAmount(IERC20 token) private view returns (uint256) {
       return _vestedAmount(token).sub(_released[address(token)]);
   }

   /**
    * @dev Calculates vested token amount
    * Linear vesting after cliff period
    */
   function _vestedAmount(IERC20 token) private view returns (uint256) {
       uint256 currentBalance = token.balanceOf(address(this));
       uint256 totalBalance = currentBalance.add(_released[address(token)]);

       if (block.timestamp < _cliff) {
           return 0;
       } else if (block.timestamp >= _start.add(_duration) || _revoked[address(token)]) {
           return totalBalance;
       } else {
           return totalBalance.mul(block.timestamp.sub(_start)).div(_duration);
       }
   }
}