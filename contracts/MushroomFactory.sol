// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
* @title MushroomFactory
* @dev Manages the creation and attributes of Mushroom NFTs
* Each pool has its own factory to create mushrooms with specific traits
* 
* VRF Integration Points:
* - Add Chainlink VRF for true randomness
* - Replaces timestamp-based randomization
* - More secure against miner manipulation

MushroomFactory
├── Species-specific factories
├── NFT minting control
├── Random trait generation
└── Pool integration

*/

// Current imports
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./MushroomNFT.sol";
import "./MushroomLib.sol";

// For VRF Integration:
// import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

contract MushroomFactory is Initializable, OwnableUpgradeSafe {
   // For VRF:
   // bytes32 internal keyHash;
   // uint256 internal fee;
   // mapping(bytes32 => address) public requestToSender;
   // mapping(bytes32 => uint256) public requestToAmount;
   // mapping(bytes32 => MushroomParams) public requestToParams;

   // struct MushroomParams {
   //     uint256 minLifespan;
   //     uint256 maxLifespan;
   //     address recipient;
   // }

   using MushroomLib for MushroomLib.MushroomData;
   using MushroomLib for MushroomLib.MushroomType;
   using SafeMath for uint256;

   event MushroomGrown(address recipient, uint256 id, uint256 species, uint256 lifespan);
   // For VRF:
   // event RandomnessRequested(bytes32 requestId, address sender);
   // event RandomnessFulfilled(bytes32 requestId, uint256 randomness);

   IERC20 public sporeToken;
   MushroomNFT public mushroomNft;
   uint256 public costPerMushroom;
   uint256 public mySpecies;
   uint256 public spawnCount;

   function initialize(
       IERC20 sporeToken_,
       MushroomNFT mushroomNft_,
       address sporePool_,
       uint256 costPerMushroom_,
       uint256 mySpecies_
       // For VRF:
       // address vrfCoordinator,
       // address link,
       // bytes32 keyHash_,
       // uint256 fee_
   ) public initializer {
       __Ownable_init();
       sporeToken = sporeToken_;
       mushroomNft = mushroomNft_;
       costPerMushroom = costPerMushroom_;
       mySpecies = mySpecies_;
       transferOwnership(sporePool_);

       // For VRF:
       // keyHash = keyHash_;
       // fee = fee_;
       // Initialize VRF:
       // VRFConsumerBase(vrfCoordinator, link)
   }

   // Current randomization method
   function _generateMushroomLifespan(uint256 minLifespan, uint256 maxLifespan) internal returns (uint256) {
       uint256 range = maxLifespan.sub(minLifespan);
       uint256 fromMin = uint256(keccak256(abi.encodePacked(block.timestamp.add(spawnCount)))) % range;
       spawnCount = spawnCount.add(1);
       return minLifespan.add(fromMin);
   }

   // VRF Version:
   // function requestRandomLifespan(uint256 minLifespan, uint256 maxLifespan, address recipient) internal returns (bytes32) {
   //     require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
   //     bytes32 requestId = requestRandomness(keyHash, fee);
   //     requestToSender[requestId] = msg.sender;
   //     requestToParams[requestId] = MushroomParams(minLifespan, maxLifespan, recipient);
   //     emit RandomnessRequested(requestId, msg.sender);
   //     return requestId;
   // }

   // function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
   //     MushroomParams memory params = requestToParams[requestId];
   //     uint256 range = params.maxLifespan.sub(params.minLifespan);
   //     uint256 lifespan = params.minLifespan.add(randomness % range);
   //     
   //     uint256 nextId = mushroomNft.totalSupply().add(1);
   //     mushroomNft.mint(params.recipient, nextId, mySpecies, lifespan);
   //     emit MushroomGrown(params.recipient, nextId, mySpecies, lifespan);
   //     emit RandomnessFulfilled(requestId, randomness);
   // }

   function getRemainingMintableForMySpecies() public view returns (uint256) {
       return mushroomNft.getRemainingMintableForSpecies(mySpecies);
   }

   // Current minting method
   function growMushrooms(address recipient, uint256 numMushrooms) public onlyOwner {
       MushroomLib.MushroomType memory species = mushroomNft.getSpecies(mySpecies);

       require(getRemainingMintableForMySpecies() >= numMushrooms, "MushroomFactory: Mushrooms to grow exceeds species cap");
       for (uint256 i = 0; i < numMushrooms; i++) {
           uint256 nextId = mushroomNft.totalSupply().add(1);
           uint256 lifespan = _generateMushroomLifespan(species.minLifespan, species.maxLifespan);
           mushroomNft.mint(recipient, nextId, mySpecies, lifespan);
           emit MushroomGrown(recipient, nextId, mySpecies, lifespan);
       }
   }

   // VRF Version:
   // function growMushroomsVRF(address recipient, uint256 numMushrooms) public onlyOwner {
   //     MushroomLib.MushroomType memory species = mushroomNft.getSpecies(mySpecies);
   //     require(getRemainingMintableForMySpecies() >= numMushrooms, "Exceeds cap");
   //     
   //     for (uint256 i = 0; i < numMushrooms; i++) {
   //         requestRandomLifespan(species.minLifespan, species.maxLifespan, recipient);
   //     }
   // }
}