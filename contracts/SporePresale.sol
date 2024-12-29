// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title SporePresale
* @dev Handles initial token distribution through ETH presale
* 
* Core Features:
* - Whitelist support for early access
* - Fixed price in ETH
* - Purchase limits per address
* - Configurable supply cap
* - Direct ETH transfer to dev wallet
*
* Fair Launch Alternative:
* - Remove whitelist functionality
* - Use Dutch Auction or LBP mechanism
* - ETH could automatically pair with SPORE in LP
* - DAO owns LP tokens instead of direct ETH to dev
* 
* DAO Owned Liquidity Benefits:
* - Protocol owns its own liquidity
* - No dependence on external LPs
* - Revenue from LP fees goes to DAO
* - More sustainable tokenomics
*/

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./SporeToken.sol";

contract SporePresale is Ownable {
   using SafeERC20 for IERC20;

   // State variables - Current Implementation
   mapping(address => bool) public whitelist;          // Would be removed in fair launch
   mapping(address => uint256) public ethSupply;       // Would track auction bids in fair launch
   uint256 public whitelistCount;                      // Not needed in fair launch
   address payable devAddress;                         // Could be DAO treasury in fair launch
   uint256 public sporePrice = 25;                    // Would be dynamic in Dutch auction
   uint256 public buyLimit = 3 * 1e18;                // Could be removed for true fair launch
   bool public presaleStart = false;                   // Would be auction timing in fair launch
   bool public onlyWhitelist = true;                  // Not needed in fair launch
   uint256 public presaleLastSupply = 15000 * 1e18;   // Initial LP supply in fair launch

   // Fair Launch Alternative State Variables:
   // uint256 public startPrice;                      // Starting auction price
   // uint256 public endPrice;                        // Floor price
   // uint256 public priceDecrementDuration;          // How fast price drops
   // address public daoTreasury;                     // DAO treasury for LP ownership
   // IUniswapV2Router02 public router;              // DEX router for LP
   // IUniswapV2Pair public pair;                    // LP pair tracking

   SporeToken public spore;

   event BuySporeSuccess(address account, uint256 ethAmount, uint256 sporeAmount);
   // Fair Launch Additional Events:
   // event LiquidityAdded(uint256 ethAmount, uint256 sporeAmount, uint256 lpTokens);
   // event AuctionPriceUpdated(uint256 newPrice);

   constructor(address payable devAddress_, SporeToken sporeToken_) public {
       devAddress = devAddress_;
       spore = sporeToken_;
       // Fair Launch would add:
       // router = IUniswapV2Router02(_router);
       // Initial LP setup logic
   }

   // Current whitelist management - Would be removed in fair launch
   function addToWhitelist(address[] memory accounts) public onlyOwner {
       for (uint256 i = 0; i < accounts.length; i++) {
           address account = accounts[i];
           require(whitelist[account] == false, "This account is already in whitelist.");
           whitelist[account] = true;
           whitelistCount = whitelistCount + 1;
       }
   }

   // Fair Launch would replace admin functions with:
   // - Auction price updates
   // - LP management functions
   // - DAO governance integration

   /**
    * @dev Main presale purchase function
    * Current: Fixed price sale with whitelist
    * 
    * Fair Launch Alternative:
    * - Dynamic pricing based on time/amount
    * - Automatic LP creation
    * - LP tokens locked in DAO
    * Example:
    * 1. Calculate current auction price
    * 2. Accept ETH at current price
    * 3. Split ETH/SPORE into LP
    * 4. Lock LP tokens in DAO
    */
   receive() external payable presaleHasStarted needHaveLastSupply {
       // Current Implementation:
       if (onlyWhitelist) {
           require(whitelist[msg.sender], "This time is only for people who are in whitelist.");
       }

       uint256 ethTotalAmount = ethSupply[msg.sender].add(msg.value);
       require(ethTotalAmount <= buyLimit, "Everyone should buy less than 3 eth.");

       uint256 sporeAmount = msg.value.mul(sporePrice);
       require(sporeAmount <= presaleLastSupply, "insufficient presale supply");
       
       presaleLastSupply = presaleLastSupply.sub(sporeAmount);
       spore.mint(msg.sender, sporeAmount);
       ethSupply[msg.sender] = ethTotalAmount;
       
       devAddress.transfer(msg.value);  // In fair launch, ETH would go to LP
       emit BuySporeSuccess(msg.sender, msg.value, sporeAmount);

       /* Fair Launch Alternative:
       uint256 currentPrice = calculateCurrentPrice();
       uint256 sporeAmount = msg.value.mul(currentPrice);
       
       // Split into LP
       uint256 lpEth = msg.value.div(2);
       uint256 lpSpore = sporeAmount.div(2);
       
       // Add Liquidity
       router.addLiquidityETH{value: lpEth}(
           address(spore),
           lpSpore,
           0, // slippage tolerance
           0,
           daoTreasury,  // LP tokens go to DAO
           block.timestamp
       );
       */
   }
}