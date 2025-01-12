// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {RedstoneOracle} from "./RedstoneOracle.sol";

interface ICurvePool {
    function add_liquidity(uint256[2] calldata amounts, uint256 min_mint_amount) external;
    function remove_liquidity_one_coin(uint256 amount, int128 i, uint256 min_amount) external;
    function get_virtual_price() external view returns (uint256);
}

contract DirectionalVault {
    using SafeERC20 for IERC20;

    // Core contracts
    IERC4626 public immutable vault;
    ICurvePool public immutable curvePool;
    IERC20 public immutable BTCN;
    IERC20 public immutable USDC;
    RedstoneOracle public immutable oracle;

    // Price feed constants
    bytes32 public constant BTC_FEED_ID = 0x4254430000000000000000000000000000000000000000000000000000000000;
    bytes32 public constant USDC_FEED_ID = bytes32("USDC"); // Replace with actual ID

    // Directional voting
    enum Direction { LONG, SHORT }
    
    struct Position {
        uint256 shares;         // Vault shares staked
        Direction direction;    // User's market view
        uint256 timestamp;      // Entry timestamp
        int256 entryPrice;     // BTC price at entry
        uint256 entryVPrice;   // Curve virtual price at entry
    }
    
    // State variables
    mapping(address => Position) public positions;
    uint256 public totalLongShares;
    uint256 public totalShortShares;
    
    // Rebalance threshold
    uint256 public constant REBALANCE_THRESHOLD = 0.05e18; // 5% threshold

    // Events
    event PositionOpened(address indexed user, uint256 shares, Direction direction, int256 btcPrice);
    event PositionClosed(address indexed user, uint256 shares, Direction direction, int256 btcPrice);
    event VaultRebalanced(uint256 lpRatio, uint256 btcnHeld);
    event DirectionalShift(uint256 longShares, uint256 shortShares, uint256 targetLpRatio);

    constructor(
        address _vault,
        address _curvePool,
        address _btcn,
        address _usdc,
        address _oracle
    ) {
        vault = IERC4626(_vault);
        curvePool = ICurvePool(_curvePool);
        BTCN = IERC20(_btcn);
        USDC = IERC20(_usdc);
        oracle = RedstoneOracle(_oracle);
    }

    function openPosition(uint256 shares, Direction direction) external {
        require(shares > 0, "Zero shares");
        
        int256 currentBtcPrice = oracle.getPrice(BTC_FEED_ID);
        require(currentBtcPrice > 0, "Invalid BTC price");
        uint256 currentVPrice = curvePool.get_virtual_price();
        
        vault.transferFrom(msg.sender, address(this), shares);
        
        Position storage position = positions[msg.sender];
        
        if (position.shares > 0) {
            if (position.direction == Direction.LONG) {
                totalLongShares -= position.shares;
            } else {
                totalShortShares -= position.shares;
            }
        }
        
        position.shares = shares;
        position.direction = direction;
        position.timestamp = block.timestamp;
        position.entryPrice = currentBtcPrice;
        position.entryVPrice = currentVPrice;
        
        if (direction == Direction.LONG) {
            totalLongShares += shares;
        } else {
            totalShortShares += shares;
        }
        
        emit PositionOpened(msg.sender, shares, direction, currentBtcPrice);
        
        _checkAndRebalance();
    }

    function closePosition() external {
        Position storage position = positions[msg.sender];
        require(position.shares > 0, "No position");
        
        uint256 shares = position.shares;
        Direction direction = position.direction;
        
        if (direction == Direction.LONG) {
            totalLongShares -= shares;
        } else {
            totalShortShares -= shares;
        }
        
        vault.transfer(msg.sender, shares);
        
        int256 currentBtcPrice = oracle.getPrice(BTC_FEED_ID);
        emit PositionClosed(msg.sender, shares, direction, currentBtcPrice);
        
        delete positions[msg.sender];
        
        _checkAndRebalance();
    }

    function getTargetLpRatio() public view returns (uint256) {
        uint256 totalShares = totalLongShares + totalShortShares;
        if (totalShares == 0) return 0.5e18; // Default to 50/50
        
        // Full range: 0% to 100% LP based on votes
        return (totalShortShares * 1e18) / totalShares;
    }

    function getCurrentLpRatio() public view returns (uint256) {
        uint256 totalAssets = vault.totalAssets();
        if (totalAssets == 0) return 0.5e18;
        
        uint256 lpBalance = IERC20(address(curvePool)).balanceOf(address(vault));
        return (lpBalance * 1e18) / totalAssets;
    }

    function _checkAndRebalance() internal {
        uint256 targetRatio = getTargetLpRatio();
        uint256 currentRatio = getCurrentLpRatio();
        
        if (Math.abs(targetRatio - currentRatio) > REBALANCE_THRESHOLD) {
            _rebalance(targetRatio);
        }
    }

    function _rebalance(uint256 targetRatio) internal {
        uint256 currentRatio = getCurrentLpRatio();
        
        if (targetRatio > currentRatio) {
            // Need more LP exposure - add BTCN to LP
            uint256 btcnToAdd = vault.totalAssets() * (targetRatio - currentRatio) / 1e18;
            _addToLp(btcnToAdd);
        } else {
            // Need more BTCN exposure - remove from LP
            uint256 lpToRemove = vault.totalAssets() * (currentRatio - targetRatio) / 1e18;
            _removeFromLp(lpToRemove);
        }
        
        emit VaultRebalanced(targetRatio, BTCN.balanceOf(address(vault)));
    }

    function _addToLp(uint256 btcnAmount) internal {
        uint256[2] memory amounts = [btcnAmount, 0];
        BTCN.approve(address(curvePool), btcnAmount);
        curvePool.add_liquidity(amounts, 0);
    }

    function _removeFromLp(uint256 lpAmount) internal {
        curvePool.remove_liquidity_one_coin(lpAmount, 0, 0); // 0 = BTCN side
    }
} 