// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title EthVesting
* @dev Contract that implements a vesting schedule for ETH distribution
* Key features:
* - Linear vesting schedule with cliff period
* - Backup beneficiary system
* - Safety measures against timestamp manipulation
* - Linear release of ETH over time to Developers or DAO.
*/

import "@openzeppelin/contracts/utils/math/Math.sol";

contract EthVesting {

   // Events for tracking distributions and deposits
   event EthReleased(uint256 amount);             // Emitted when ETH is released to primary beneficiary
   event EthReleasedBackup(uint256 amount);       // Emitted when ETH is released to backup beneficiary
   event PaymentReceived(address from, uint256 amount); // Emitted when ETH is received

   // Core state variables
   address payable private _beneficiary;          // Primary recipient of vested ETH
   address payable private _backupBeneficiary;    // Backup recipient if primary doesn't claim
   uint256 private _cliff;                        // Timestamp when vesting begins
   uint256 private _start;                        // Start timestamp of vesting period
   uint256 private _duration;                     // Duration of entire vesting period
   uint256 private _backupReleaseGracePeriod;    // Grace period before backup can claim
   uint256 private _released;                     // Amount of ETH already released

   /**
    * @dev Constructor sets up vesting schedule parameters
    * @param beneficiary Primary recipient of vested ETH
    * @param backupBeneficiary Backup recipient if primary doesn't claim
    * @param start Timestamp when vesting begins
    * @param cliffDuration Duration before any ETH can be claimed (in seconds)
    * @param duration Total vesting duration (in seconds)
    * @param backupReleaseGracePeriod Grace period before backup can claim (in seconds)
    */
   constructor (
       address payable beneficiary,
       address payable backupBeneficiary,
       uint256 start,
       uint256 cliffDuration,
       uint256 duration,
       uint256 backupReleaseGracePeriod
   ) public {
       // Validation
       require(beneficiary != address(0), "EthVesting: beneficiary is the zero address");
       require(cliffDuration <= duration, "EthVesting: cliff is longer than duration");
       require(duration > 0, "EthVesting: duration is 0");
       require(start.add(duration) > block.timestamp, "EthVesting: final time is before current time");

       // Set core parameters
       _beneficiary = beneficiary;
       _backupBeneficiary = backupBeneficiary;
       _duration = duration;
       _cliff = start.add(cliffDuration);
       _start = start;
       _backupReleaseGracePeriod = backupReleaseGracePeriod;
   }

   // Getter functions for contract parameters...

   /**
    * @dev Main function for releasing vested ETH to beneficiary
    * Calculates and transfers available ETH based on vesting schedule
    */
   function release() public {
       uint256 unreleased = _releasableAmount();
       require(unreleased > 0, "EthVesting: no eth is due");

       _released = _released.add(unreleased);
       _beneficiary.transfer(unreleased);

       emit EthReleased(unreleased);
   }

   /**
    * @dev Calculates amount of ETH that has vested but hasn't been released
    */
   function _releasableAmount() private view returns (uint256) {
       return _vestedAmount().sub(_released);
   }

   /**
    * @dev Calculates total amount of ETH that has vested based on time
    */
   function _vestedAmount() private view returns (uint256) {
       uint256 currentBalance = address(this).balance;
       uint256 totalBalance = currentBalance.add(_released);

       if (block.timestamp < _cliff) {
           return 0;
       } else if (block.timestamp >= _start.add(_duration)) {
           return totalBalance;
       } else {
           return totalBalance.mul(block.timestamp.sub(_start)).div(_duration);
       }
   }

   /**
    * @dev Allows backup beneficiary to claim ETH after grace period
    * Only callable after vesting period + grace period
    */
   function backupRelease() public {
       require(block.timestamp >= _start.add(_duration).add(_backupReleaseGracePeriod));
       _backupBeneficiary.transfer(address(this).balance);

       emit EthReleasedBackup(address(this).balance);
   }

   /**
    * @dev Allows contract to receive ETH
    */
   receive() external payable virtual {
       emit PaymentReceived(msg.sender, msg.value);
   }
}