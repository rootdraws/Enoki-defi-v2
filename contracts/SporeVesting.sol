// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// File Processed by Claude.AI Sonnet on 1/11/25.

// SPORE VESTING CONTRACT | FACTORY INSTANCE
// This is a vesting contract for the Spore ecosystem. It is used to vest tokens for the vaults.

contract SporeVesting is Initializable {
    using SafeERC20 for IERC20;

    // Errors
    error NotVault();
    error NoVestedTokens();

    // Events
    event TokensReceived(address token, uint256 amount, uint256 timestamp);
    event TokensReleased(address token, uint256 amount, uint256 timestamp);

    // Vesting schedule for each token
    struct VestingSchedule {
        uint256 lastRelease;
        uint256 startAmount;
    }
    
    // State variables
    address public vault;
    uint256 public constant VESTING_DURATION = 30 days;
    mapping(address => VestingSchedule) public vestingSchedules;
    string public name;
    string public symbol;

    // Constructor
    constructor() {
        _disableInitializers();
    }

    // Initialize the vesting contract
    function initialize(
        address _vault,
        string memory _name,
        string memory _symbol
    ) external initializer {
        vault = _vault;
        name = _name;
        symbol = _symbol;
    }

    // Deposit tokens to be vested
    function depositTokens(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Start new vesting schedule for this deposit
        vestingSchedules[token] = VestingSchedule({
            lastRelease: block.timestamp,
            startAmount: IERC20(token).balanceOf(address(this))
        });

        emit TokensReceived(token, amount, block.timestamp);
    }

    // Releases vested tokens to the vault
    function releaseVested(address token) external {
        uint256 vestedAmount = _calculateVestedAmount(token);
        if (vestedAmount == 0) revert NoVestedTokens();

        vestingSchedules[token].lastRelease = block.timestamp;
        IERC20(token).safeTransfer(vault, vestedAmount);

        emit TokensReleased(token, vestedAmount, block.timestamp);
    }

    // Calculate amount of tokens that have vested
    function _calculateVestedAmount(address token) internal view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[token];
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance == 0) return 0;

        uint256 timePassed = block.timestamp - schedule.lastRelease;
        if (timePassed >= VESTING_DURATION) {
            return balance;
        }

        return (balance * timePassed) / VESTING_DURATION;
    }

    // Read currently vested amount
    function vestedAmount(address token) external view returns (uint256) {
        return _calculateVestedAmount(token);
    }
} 