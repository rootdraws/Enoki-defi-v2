# Overview

Deployment happens in two main stages:

1. Core Protocol Deployment (Token infrastructure and economic base)
2. Gameplay Mechanics (Pools, NFTs, and supporting systems)

## Stage 1: Enoki Core

## Prerequisites

```solidity
// These addresses must exist before deployment
address public daoAddress;        // Controls protocol
address public enokiTokenAddress; // Main governance token
address public devMultisig;       // Team security

### Core Token Deployment

// SPORE Token Deployment
// Note: This is the reward/utility token
SporeToken spore = new SporeToken();
spore.mint(initialSupply);
spore.transferOwnership(daoAddress);
// Prevent front-running on initial liquidity
spore.grantInitialTransferRights(devMultisig);

// Payment Splitting Setup
// Handles presale proceeds:
// - 66.6% to vesting (6 months)
// - 33.3% to liquidity (locked)
PaymentSplitter splitter = new PaymentSplitter(
    [vestingAddress, liquidityAddress],
    [666, 333]
);

// Dev Fund Vesting
// 6 month vesting for development funds
TokenVesting devVesting = new TokenVesting(
    devMultisig,
    block.timestamp,
    180 days, // 6 month cliff
    180 days  // 6 month vest
);

### Presale Setup

// Controls initial token distribution
SporePresale presale = new SporePresale(
    devMultisig,
    sporeToken
);
// Lock SPORE supply
spore.transfer(address(presale), presaleSupply);
// Add whitelisted addresses in batches to save gas
presale.addToWhitelist(whitelistBatch1);

### Mission System Setup

// Mission0 = Base reward distribution system
// Using proxy pattern for upgradability
Mission0Logic logic = new Mission0Logic();
Mission0Proxy proxy = new Mission0Proxy(
    logic.address,
    daoAddress
);
Mission0 mission = Mission0(address(proxy));

// Escrow for mission rewards
TokenPool missionEscrow = new TokenPool();
spore.transfer(address(missionEscrow), 210_000e18);

### Geyser System Setup

// ENOKI rewards distribution system
// Also upgradeable
EnokiGeyserLogic geyserLogic = new EnokiGeyserLogic();
EnokiGeyserProxy geyserProxy = new EnokiGeyserProxy(
    geyserLogic.address,
    daoAddress
);

### Stage 1a: Liquidity Setup

// After presale begins:
// 1. Create Uniswap pool
IUniswapV2Router02 router = IUniswapV2Router02(ROUTER_ADDRESS);
router.addLiquidity(
    spore.address,
    weth.address,
    5000e18,    // 5000 SPORE
    300e18,     // 300 ETH
    0, 0,       // No slippage protection for initial LP
    address(this),
    block.timestamp
);

// 2. Lock LP tokens
TokenVesting lpVesting = new TokenVesting(
    daoAddress,
    block.timestamp + 30 days,  // 1 month cliff
    730 days                    // 24 month vest
);

### Stage 2: Gameplay Mechanics

// NFT System Setup
MushroomNFT nft = new MushroomNFT();
// One factory per pool for different species
MushroomFactory[] factories;
for (pool in pools) {
    factories.push(new MushroomFactory(pool));
}

// Metadata System
MetadataRegistry registry = new MetadataRegistry();
MetadataResolver resolver = new MetadataResolver(registry);

// Pool Setup
SporePools[] pools = deployPools();  // Multiple pools for different strategies

// Connect Components
for (factory in factories) {
    nft.grantMintingRights(factory);
    resolver.setFactoryPermissions(factory);
}

// Final System
Incubator incubator = new Incubator();
