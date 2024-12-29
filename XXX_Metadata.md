# Mushroom NFT System - How It Works

## Components

### MetadataResolver (Hub)
- Central registry that maps NFT contracts → their metadata adapters
- All external calls go through here first
- Handles permissions (admin + lifespan modifiers)
- Routes calls to the right adapter

### MetadataAdapter (Interface)
- Abstract contract defining what adapters must do:
  - Get mushroom data
  - Set lifespan
  - Check if burnable/stakeable
- Has role system for lifespan changes

### MushroomAdapter (Implementation)
- Actual implementation for Mushroom NFTs
- Talks directly to MushroomNFT contract
- All mushrooms can be staked/burned by default
- Forwards lifespan changes to NFT contract

## How They Work Together

1. Setup:
   ```
   MetadataResolver ─registers→ MushroomAdapter ─talks to→ MushroomNFT
   ```

2. Flow for operations:
   ```
   External Call → MetadataResolver → Correct Adapter → NFT Contract
   ```

3. Permissions:
   - Admin: Can add/change adapters
   - Lifespan Modifier: Can change NFT lifespans

## Extension Pattern

To add new NFT type:
1. Make new adapter implementing MetadataAdapter
2. Deploy it
3. Register it in MetadataResolver

That's it - system now supports the new NFT type!