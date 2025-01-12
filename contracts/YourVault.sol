contract YourVault {
    RedstoneOracle public oracle;

    constructor(address _oracle) {
        oracle = RedstoneOracle(_oracle);
    }

    function someFunction() public view {
        int256 btcPrice = oracle.getBTCPrice();
        int256 ethPrice = oracle.getETHPrice();
        
        // Or get multiple prices at once
        bytes32[] memory feeds = new bytes32[](2);
        feeds[0] = oracle.BTC_FEED_ID();
        feeds[1] = oracle.ETH_FEED_ID();
        int256[] memory prices = oracle.getPrices(feeds);
    }
} 