# Process

## MILESTONE 0: IMPORT

### Modernization | Updates [This is being set up on Arbitrum Sepolia Testnet]

- [Oracle](https://medium.com/@parsaadana4/redstone-defi-oracle-integration-step-by-step-guide-3726b3f319e1)

- Need to work through the Vault structure - I like the directional vault, let's pick one, and ship it to testnet, then expand to multiple for mainnet vaults.
- Minimalist pass through with Claude -- If there is a way to make the code more essential, and clear, then do it.
- Remove all components of MiniMe Tokens, and replace with OpenZeppelin ERC20Votes, so that the project is compatible with Tally.
- Enable transfer of ownership to the gnosis safe on tally, so that tally can take onchain actions.
- Upgrade Randomizer to VRF Gelato
- Create a Spore Distribution system, which involves governance votes, and multiple Vault Campaigns.
- Upgrade to incentivized 4626 Strategy Vaults, so Spore can be distributed for depositing within the 4626 Vault, and these can be LP Staking strategies that use Curve Pools, or Camelot Pools, or Compound Strategy Vaults.
  - [Vaultcraft Repo](https://github.com/Popcorn-Limited) Uses Gelato for Automation.

### Scripts

- Modernize all Scripts - and make sure that they work with the contracts that have been updated.
- Replace all Univ2 with CamelotRouter. [All of the Univ2 Code are in the Scripts.]
  - [CONTRACT](https://docs.camelot.exchange/contracts/arbitrum/sepolia-testnet)

### Architecture | Flow

- Examine Tokenomics, and how it integrates with popCORN and the Hidden Husk.
- Consider how the v0 Membership allows expansion to include other ad campaigns.

#### Note

1. An LP DAO which raises BTCN to farm BTCN - USDC for Kernels, to accrue CORN.
2. A project which secures a popCORN subsidy from Cornstars.
3. An LP DAO which builds a popCORN position, to be able to extract Bribe Tokens from the Hidden Husk.
4. There needs to be a mechanism to raise another round of BTCN, to pair with the Bribe Tokens from the Hidden Husk, so that the LP DAO could be expanded, and the artists involved can be supported by outreach grants to those other areas.

LP or Strategy Vault Deposits → Earn SPORE → Mint Mushrooms → Stake in Geyser → Earn ENOKI

And ENOKI should vote to control the protocol, which is composed of:

- SPORE - BTCN LP [This supply eventually gets burned, and is the source of new campaigns.]
- ENOKI - BTCN LP [This eventually matures and becomes the token of the platform.]
- BTCN - USDC LP [This is formed by initial capital deposit.]
- popCORN earning Bribes [This is formed by Airdrop and Kernel Earning.]
- BRIBE - BTCN LP [These are formed from Hidden Husk & New Artist Campaigns.]

All of this needs to be reflected in the Infrastructure.

You also need to solve how Contributors are going to be paid.

- How do you pay yourself for Building | BD | Maintainening | Art
- How do you pay artists for doing the next bit of art?
- How do you pay video / content / education to advertise each campaign?

Questions:

- Do you have built in pacing for Spore Distributions, which match Campaign Batch releases, so you can line up new campaigns?

## MILESTONE 1: LAUNCH ON ARBITRUM SEPOLIA

CORN Testnet | Migration |

- Migrate all assets to Corn | BTCN
- You need to Upgrade any MultiSig | Tally Connections to Den
- You need to find a Camelot Router Deployment

### Documentation | Funding | Partnerships

- Write Docs.
- Draw out Infrastructure Capital Flows.
- Clean up Github Documentation.
- Apply to Cornstars.

### NFT MetaData | Mushroom Types

- Consider thematic Mushrooms which align with different target audiences for launch, and then prospective types of mushrooms which would represent future campaigns.

### NFT Marketplace

- Fork and solve the Enoki DeFi Marketplace Contracts

### Art | UX

- Create Art for each of the NFTs.
- Create a Art UI | UX.
  Music and Voiceovers for "Welcome Forager"

### Frontend Development

- Connect everything into a Frontend.

## MILESTONE 2: WORKING CORN TESTNET DEMO

- Launch Proceedures | Presale Mechanics.
- Code for popCORN and Hidden Husk.
- Outreach for Campaign Partnerships -- This information goes into Mushroom Metadata Types.
- Campaign Roadmap.

## MILESTONE 3: LAUNCH
