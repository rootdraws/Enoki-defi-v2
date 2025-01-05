require("@nomicfoundation/hardhat-ethers");
require("dotenv").config();

module.exports = {
  solidity: "0.8.17",
  networks: {
    arbitrumSepolia: {
      url: process.env.ARBITRUM_SEPOLIA_RPC_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
    cornMaizenet: {
      url: process.env.CORN_MAIZENET_RPC_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
    cornTestnet: {
      url: process.env.CORN_TESTNET_RPC_URL,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY],
    },
  },
};