// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

contract RedstoneOracle {
    // The address of the price feed adapter on Corn
    address public constant PRICE_FEED_ADAPTER = 0xD15862FC3D5407A03B696548b6902D6464A69b8c;

    // Common tokens (add more as needed)
    bytes32 public constant BTC_FEED_ID = 0x4254430000000000000000000000000000000000000000000000000000000000; // "BTC"
    bytes32 public constant ETH_FEED_ID = 0x4554480000000000000000000000000000000000000000000000000000000000; // "ETH"
    // Add more feed IDs as needed

    // Get price for any feed ID
    function getPrice(bytes32 feedId) public view returns (int256) {
        (, int256 price,,,) = IAggregatorV3Interface(PRICE_FEED_ADAPTER).latestRoundData();
        return price;
    }

    // Convenience functions for common tokens
    function getBTCPrice() public view returns (int256) {
        return getPrice(BTC_FEED_ID);
    }

    function getETHPrice() public view returns (int256) {
        return getPrice(ETH_FEED_ID);
    }

    // Get multiple prices in one call
    function getPrices(bytes32[] calldata feedIds) public view returns (int256[] memory) {
        int256[] memory prices = new int256[](feedIds.length);
        for (uint i = 0; i < feedIds.length; i++) {
            prices[i] = getPrice(feedIds[i]);
        }
        return prices;
    }

    // Optional: Check if a price feed exists and when it was last updated
    function getLastUpdateTime(bytes32 feedId) public view returns (uint256) {
        (,,,uint256 updatedAt,) = IAggregatorV3Interface(PRICE_FEED_ADAPTER).latestRoundData();
        return updatedAt;
    }
} 