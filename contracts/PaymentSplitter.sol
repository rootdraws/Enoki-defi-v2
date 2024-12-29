// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title PaymentSplitter
* @dev Contract that splits ETH payments between multiple recipients based on shares
* Can be used with EthVesting for controlled release + splitting of payments
* 
* Example Flow:
* 1. ETH Vesting releases funds after vesting period
* 2. Released funds go to PaymentSplitter
* 3. PaymentSplitter divides based on shares
* 4. Recipients claim their portions
*/

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract PaymentSplitter is Context {

   // Events for tracking payments and shares
   event PayeeAdded(address account, uint256 shares);
   event PaymentReleased(address to, uint256 amount);
   event PaymentReceived(address from, uint256 amount);

   // Core state variables
   uint256 private _totalShares;       // Total shares allocated
   uint256 private _totalReleased;     // Total ETH released so far
   mapping(address => uint256) private _shares;    // Shares per address
   mapping(address => uint256) private _released;  // Amount released per address
   address[] private _payees;          // List of payee addresses

   /**
    * @dev Sets up initial payees and their shares
    * @param payees Array of recipient addresses
    * @param shares Array of share amounts (must match payees length)
    */
   constructor (address[] memory payees, uint256[] memory shares) public payable {
       require(payees.length == shares.length, "PaymentSplitter: payees and shares length mismatch");
       require(payees.length > 0, "PaymentSplitter: no payees");

       for (uint256 i = 0; i < payees.length; i++) {
           _addPayee(payees[i], shares[i]);
       }
   }

   /**
    * @dev Allows contract to receive ETH
    */
   receive () external payable virtual {
       emit PaymentReceived(_msgSender(), msg.value);
   }

   /**
    * @dev Gets total shares allocated
    */
   function totalShares() public view returns (uint256) {
       return _totalShares;
   }

   /**
    * @dev Gets total ETH released
    */
   function totalReleased() public view returns (uint256) {
       return _totalReleased;
   }

   /**
    * @dev Gets shares for specific account
    */
   function shares(address account) public view returns (uint256) {
       return _shares[account];
   }

   /**
    * @dev Gets amount released to specific account
    */
   function released(address account) public view returns (uint256) {
       return _released[account];
   }

   /**
    * @dev Gets payee address by index
    */
   function payee(uint256 index) public view returns (address) {
       return _payees[index];
   }

   /**
    * @dev Release owed payment to specific account
    * Calculates amount based on shares and previous withdrawals
    * @param account Address to release payment to
    */
   function release(address payable account) public virtual {
       require(_shares[account] > 0, "PaymentSplitter: account has no shares");

       uint256 totalReceived = address(this).balance.add(_totalReleased);
       uint256 payment = totalReceived.mul(_shares[account]).div(_totalShares).sub(_released[account]);

       require(payment != 0, "PaymentSplitter: account is not due payment");

       _released[account] = _released[account].add(payment);
       _totalReleased = _totalReleased.add(payment);

       account.transfer(payment);
       emit PaymentReleased(account, payment);
   }

   /**
    * @dev Internal function to add new payee
    * @param account Payee address
    * @param shares_ Number of shares for payee
    */
   function _addPayee(address account, uint256 shares_) private {
       require(account != address(0), "PaymentSplitter: account is the zero address");
       require(shares_ > 0, "PaymentSplitter: shares are 0");
       require(_shares[account] == 0, "PaymentSplitter: account already has shares");

       _payees.push(account);
       _shares[account] = shares_;
       _totalShares = _totalShares.add(shares_);
       emit PayeeAdded(account, shares_);
   }
}