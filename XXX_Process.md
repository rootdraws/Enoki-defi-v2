# Process

## MILESTONE 0: IMPORT

### Migrations | Updates [This is being set up on Arbitrum Sepolia Testnet]

- Modernizing with Claude, and then going through each of the original contracts, to make sure that all functions there, in each file, and they are also modernized. [CURRENT]

- Replace all Univ2 with CamelotRouter.
  - [CONTRACT](https://docs.camelot.exchange/contracts/arbitrum/sepolia-testnet)
- Remove all components of MiniMe Tokens, and replace with OpenZeppelin ERC20Votes, so that the project is compatible with Tally.
- Enable transfer of ownership to the gnosis safe on tally, so that tally can take onchain actions.
- Upgrade Randomizer to VRF Gelato

### Architecture | Flow

- Examine Tokenomics, and how it integrates with popCORN and the Hidden Husk.
- Consider how the v0 Membership allows expansion to include other ad campaigns.

#### Note

1. An LP DAO which raises BTCN to farm BTCN - USDC for Kernels, to accrue CORN.
2. A project which secures a popCORN subsidy from Cornstars.
3. An LP DAO which builds a popCORN position, to be able to extract Bribe Tokens from the Hidden Husk.
4. There needs to be a mechanism to raise another round of BTCN, to pair with the Bribe Tokens from the Hidden Husk, so that the LP DAO could be expanded, and the artists involved can be supported by outreach grants to those other areas.

TOKEN FLOW?

ETH Staking → Earn SPORE → Mint Mushrooms → Stake in Geyser → Earn ENOKI

The Flows ought to look like a DAO that builds more and more value for itself, and then directs that value toward these membership tokens.

So, the NFT Art is ephermeral, and exists to distribute ENOKI, which is the membership token.
On a Seasonal Timeline, the spores should turn all into ENOKI.
The NFTs should turn into ENOKI.
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

- How does this structure reflect Based Rovers -- meaning, how is value pulled out?
- Do you have built in pacing for Spore Distributions, which match Campaign Batch releases, so you can line up new campaigns?

### Scripts | Tests

- Translate all scripts from ts to js.
- Translate all tests from ts to js.

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
