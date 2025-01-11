// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

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

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _vault,
        string memory _name,
        string memory _symbol
    ) external initializer {
        vault = _vault;
        name = _name;
        symbol = _symbol;
    }

    /**
     * @notice Deposit tokens to be vested
     * @dev Anyone can deposit tokens which will vest over 30 days
     * @param token The ERC20 token to vest
     * @param amount Amount of tokens to vest
     */
    function depositTokens(address token, uint256 amount) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Start new vesting schedule for this deposit
        vestingSchedules[token] = VestingSchedule({
            lastRelease: block.timestamp,
            startAmount: IERC20(token).balanceOf(address(this))
        });

        emit TokensReceived(token, amount, block.timestamp);
    }

    /**
     * @notice Releases vested tokens to the vault
     * @param token The token to release
     */
    function releaseVested(address token) external {
        uint256 vestedAmount = _calculateVestedAmount(token);
        if (vestedAmount == 0) revert NoVestedTokens();

        vestingSchedules[token].lastRelease = block.timestamp;
        IERC20(token).safeTransfer(vault, vestedAmount);

        emit TokensReleased(token, vestedAmount, block.timestamp);
    }

    /**
     * @notice Calculate amount of tokens that have vested
     * @param token The token to check
     * @return Amount of tokens that can be released
     */
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

    /**
     * @notice View function to check currently vested amount
     * @param token The token to check
     * @return Amount of tokens currently vested
     */
    function vestedAmount(address token) external view returns (uint256) {
        return _calculateVestedAmount(token);
    }
} 