/**
 * @title EnokiTreasury
 * @dev Manages:
 * - LP fee collection
 * - CORN voting rights
 * - Bribe collection
 * - Artist payments
 */
contract EnokiTreasury {
    // LP Management
    mapping(address => uint256) public lpBalances;
    
    // CORN voting
    function voteCORN(address[] calldata targets, uint256[] calldata amounts);
    
    // Bribe collection
    function collectBribes(address[] calldata markets);
    
    // Revenue sharing
    function distributeRevenue(
        uint256 daoShare,
        uint256 artistShare,
        uint256 lpShare
    );
}

// This is something to do with the tasks that the DAO is doing -- such as voting on popCORN, and collecting Bribes, and there needs to be a Revshare contract.