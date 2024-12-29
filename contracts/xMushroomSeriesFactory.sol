/**
 * @title MushroomSeriesFactory
 * @dev Creates new mushroom series for different communities
 */
contract MushroomSeriesFactory {
    struct Series {
        string name;          // Community name
        address lpToken;      // Community's LP token
        uint256 sporeRate;    // SPORE earning rate
        uint256 maxSupply;    // Max mushrooms for series
        address artist;       // Artist payment address
    }
    
    mapping(uint256 => Series) public series;
    uint256 public currentSeries;
}

// This is based on the idea that we would be expanding new Art pieces, for new partners, sort of a business development LP Farming x Art Campaign thing.abi

/*

I'm thinking of making this a type of marketing DAO, where the NFTs are artworks, which are thematically targeted toward specific groups -- This would be other projects in the ecosystem, with their own branding and token. 

I want to be able to expand the ENOKI club, by offering these targeted sales, of mushrooms. If the new mushrooms are Yield Farm to earn Spore. 

We need a way to repeat the pattern. 

Stake LP -> Earn Spore -> Burn Spore for Mushroom -> Plant Mushroom -> Earn ENOKI. 

But the LP needs to be able to earn enough fees to build out the long term treasury. 

.:. 

A key part of this is that this whole project is meant to farm this airdrop, which is sort of like veCRV. Basically, you get this popCORN, which is like veCRV, you can vote to direct CORN emissions toward things. 

And then, you earn as a DAO, by what you vote for -- which is what this hidden hand type bribe market is about. 

We can get a big stack of bribes as a DAO, and also build up LPs as a DAO, and expand to new projects, with small batches of new art for new Mushroom NFTs. 

So you're kind of expanding a MYCELIAL NETWORK -- amongst you know different defi communities, as somewhere between a Yield Farm, and an LP DAO, and a veDAO, and an Art x Marketing Collective.

*/