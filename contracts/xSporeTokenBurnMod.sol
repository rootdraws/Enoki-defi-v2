// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title SporeToken
 * @dev Intermediate token that's burned to create Mushroom NFTs
 * 
 * Token Flow:
 * 1. SPORE earned from LP staking
 * 2. SPORE burned to mint Mushrooms
 * 3. Mushrooms staked for ENOKI
 * 4. Dead Mushrooms burned for final ENOKI distribution
 * 
 * graph LR
    A[Stake LP] --> B[Earn SPORE]
    B --> C[Burn SPORE to Mint Mushrooms]
    C --> D[Stake Mushrooms]
    D --> E[Earn ENOKI]
    D --> F[Mushroom Dies]
    F --> G[Burn Mushroom to Get Final ENOKI]
 * 
 */
contract SporeToken is ERC20, Ownable, Pausable {
    // Approved minters (staking pools)
    mapping(address => bool) public minters;
    
    // Approved burners (Mushroom Factory)
    mapping(address => bool) public burners;
    
    // Track total burned
    uint256 public totalBurned;

    // Events
    event MinterAdded(address minter);
    event MinterRemoved(address minter);
    event BurnerAdded(address burner);
    event BurnerRemoved(address burner);
    event SporesBurned(address indexed burner, uint256 amount, string reason);

    constructor() ERC20("Spore Token", "SPORE") {
        // Initial supply handled by minters
    }

    /**
     * @dev Pools mint SPORE as rewards
     */
    function mint(address to, uint256 amount) external {
        require(minters[msg.sender], "Not authorized to mint");
        _mint(to, amount);
    }

    /**
     * @dev Burn SPORE to mint Mushrooms
     * Only callable by authorized burners (Mushroom Factory)
     */
    function burnFrom(address account, uint256 amount) external {
        require(burners[msg.sender], "Not authorized to burn");
        _burn(account, amount);
        totalBurned += amount;
        emit SporesBurned(account, amount, "Mushroom Minting");
    }

    // Access Control Functions
    function addMinter(address minter) external onlyOwner {
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    function addBurner(address burner) external onlyOwner {
        burners[burner] = true;
        emit BurnerAdded(burner);
    }

    function removeBurner(address burner) external onlyOwner {
        burners[burner] = false;
        emit BurnerRemoved(burner);
    }

    // Emergency Functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}