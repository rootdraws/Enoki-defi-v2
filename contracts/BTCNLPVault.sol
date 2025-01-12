// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {RedstoneOracle} from "./RedstoneOracle.sol";

interface ICurvePool {
    function add_liquidity(uint256[2] calldata amounts, uint256 min_mint_amount) external;
}

contract BTCNLPVault is ERC4626 {
    using SafeERC20 for IERC20;

    ICurvePool public immutable curvePool;
    IERC20 public immutable USDC;
    IERC20 public immutable BTCN;
    IERC20 public immutable lpToken;

    // Redstone oracle integration
    RedstoneOracle public immutable oracle;
    bytes32 public constant BTC_FEED_ID = 0x4254430000000000000000000000000000000000000000000000000000000000;
    bytes32 public constant USDC_FEED_ID = bytes32("USDC"); // Replace with actual USDC feed ID

    constructor(
        address _btcn,
        address _usdc,
        address _curvePool,
        address _lpToken,
        address _oracle
    ) ERC4626(IERC20(_btcn), "BTCN LP Vault", "vBTCN") {
        BTCN = IERC20(_btcn);
        USDC = IERC20(_usdc);
        curvePool = ICurvePool(_curvePool);
        lpToken = IERC20(_lpToken);
        oracle = RedstoneOracle(_oracle);
    }

    function totalAssets() public view override returns (uint256) {
        uint256 lpBalance = lpToken.balanceOf(address(this));
        return _convertLPToBTCN(lpBalance);
    }

    function _convertLPToBTCN(uint256 lpAmount) internal view returns (uint256) {
        if (lpAmount == 0) return 0;
        
        uint256 btcnInPool = BTCN.balanceOf(address(curvePool));
        uint256 usdcInPool = USDC.balanceOf(address(curvePool));
        uint256 totalLp = lpToken.totalSupply();

        // Get oracle prices using RedstoneOracle
        int256 btcPrice = oracle.getPrice(BTC_FEED_ID);
        int256 usdcPrice = oracle.getPrice(USDC_FEED_ID);
        
        require(btcPrice > 0 && usdcPrice > 0, "Invalid oracle prices");

        uint256 lpShare = (lpAmount * 1e18) / totalLp;
        uint256 btcnValue = (btcnInPool * lpShare) / 1e18;
        uint256 usdcValue = (usdcInPool * lpShare * uint256(usdcPrice)) / (uint256(btcPrice) * 1e18);

        return btcnValue + usdcValue;
    }

    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal override {
        super._deposit(caller, receiver, assets, shares);

        BTCN.safeTransferFrom(caller, address(this), assets);
        
        BTCN.approve(address(curvePool), assets);
        uint256[2] memory amounts = [assets, 0];
        curvePool.add_liquidity(amounts, 0);
    }
} 