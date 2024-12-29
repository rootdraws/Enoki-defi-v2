# Process

## MILESTONE 0: IMPORT

### Migrations | Updates [This is being set up on Arbitrum Sepolia Testnet]

- You need to go through each of the Contracts, and verify that all of the functions and information from the original contracts are there post Claude. [CURRENT]

- Ask Claude to update security for each contract.
- You need to go through and remove all instances of SafeMath.
- You need to go through and replace all Univ2 with CamelotRouter.
  - [CONTRACT](https://docs.camelot.exchange/contracts/arbitrum/sepolia-testnet)
- You need to go through and remove all components of MiniMe Tokens, and replace with OpenZeppelin ERC20Votes, so that the project is compatible with Tally.
- You need to make sure you can transfer ownership to the gnosis safe on tally, so that tally can take onchain actions.
- You need to check and see what the vulnerabilities were with the ERC721 on the original project.

### Architecture | Flow

- You need to examine Tokenomics, and how it integrates with popCORN and the Hidden Husk.
- You need to consider how the v0 Membership allows expansion to include other ad campaigns.

#### Note

Alchemistresses needed a type of structure, which allowed for expansion to other areas. If the premise of the project is as follows:

1. Spore is hot air.
2. NFTs are ephemeral.
3. Enoki is your objective.

And then ENOKI holders determine the rate of SPORE.

The value must be in the BTCN that is deposited into the treasury, and the CORN allocation.

This means the focus needs to be:

1. An LP DAO which raises BTCN to farm BTCN - USDC for Kernels, to accrue CORN.
2. A project which secures a popCORN subsidy from Cornstars.
3. An LP DAO which builds a popCORN position, to be able to extract Bribe Tokens from the Hidden Husk.
4. There needs to be a mechanism to raise another round of BTCN, to pair with the Bribe Tokens from the Hidden Husk, so that the LP DAO could be expanded, and the artists involved can be supported by outreach grants to those other areas.

TOKEN FLOW

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

- How do you pay yourself for building this?
- How do you pay yourself for securing the next client?
- How do you pay yourself for doing the code maintenance for each campaign?
- How do you pay yourself for doing the Project management for each campaign?
- How do you pay your artists for doing the next bit of art?
- How do you pay video / content / education to advertise each campaign?

Questions:

- How does this structure reflect Based Rovers -- meaning, how is value pulled out?
- How does this structure pay artists | Business Developers | Project Managers for creating new Campaigns based on Hidden Husk Bribes?
- Do you have built in pacing for Spore Distributions, which match Campaign Batch releases, so you can line up new campaigns?

### Scripts | Tests

- You need to translate all scripts from ts to js.
- You need to translate all tests from ts to js.

## MILESTONE 1: LAUNCH ON ARBITRUM SEPOLIA

CORN Testnet | Migration |

- You need to Migrate all assets to Corn | BTCN
- You need to Upgrade Randomizer to VRF Gelato
- You need to Upgrade any MultiSig | Tally Connections to Den
- You need to find a Camelot Router Deployment

### Documentation | Funding | Partnerships

- You need to write out Docs.
- You need to draw out Infrastructure Capital Flows.
- You need to clean up Github Documentation.
- You need to apply to Cornstars.
- How do you decentralize yourself out a job?

### NFT MetaData | Mushroom Types

- You need to consider thematic Mushrooms which align with different target audiences for launch, and then prospective types of mushrooms which would represent future campaigns.

### NFT Marketplace

- You need to fork and solve the Enoki DeFi Marketplace Contracts

### Art | UX

- You need to create Art for each of the NFTs.
- You need to create a Art UI | UX.
- You need Music and Voiceovers for "Welcome Forager"

### Frontend Development

- You need to Connect everything into a Frontend.

## MILESTONE 2: WORKING CORN TESTNET DEMO

- You need to Decide on Launch Proceedures | Presale Mechanics.
- You need to solidify code for popCORN and Hidden Husk.
- You need to outreach for Campaign Partnerships -- This information goes into Mushroom Metadata Types.
- You need to create a Campaign Roadmap.
- Ask for help | funding.

## MILESTONE 3: LAUNCH
