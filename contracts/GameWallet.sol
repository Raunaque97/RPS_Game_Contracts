// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract GameWallet is AccessControl {
    struct withdrawalRequest {
        uint256 amount;
        uint256 timestamp;
    }
    mapping(address => uint256) public deposits;
    mapping(address => withdrawalRequest) public withdrawalQueue;
    uint public treasuryBal;
    // innitialize erc20
    IERC20 public erc20;

    bytes32 public constant ORGANISER_ROLE = keccak256("ORGANISER"); // game organizerss who slash deposits

    constructor(address _erc20Address) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        erc20 = IERC20(_erc20Address);
    }

    function deposit(uint amt) external {
        erc20.transferFrom(msg.sender, address(this), amt);
        deposits[msg.sender] += amt;
    }

    function transfer(address to, address from, uint amt) external {
        require(hasRole(ORGANISER_ROLE, msg.sender), "Caller is not authorized to transfer");
        require(deposits[from] >= amt, "Not enough deposit to transfer");
        deposits[from] -= amt;
        deposits[to] += amt;
    }

    function transferToTreasury(address from, uint amt) external {
        require(hasRole(ORGANISER_ROLE, msg.sender), "Caller is not authorized to transfer");
        require(deposits[from] >= amt, "Not enough deposit to transfer");
        deposits[from] -= amt;
        treasuryBal += amt;
    }

    function slash(address user, uint fine) external {
        require(deposits[user] >= fine, "Not enough deposit to slash");
        require(hasRole(ORGANISER_ROLE, msg.sender), "Caller is not authorized to slash");
        deposits[user] = deposits[user] - fine;
        treasuryBal += fine;
    }

    // moves the caller to widhtdrawal queue
    function startWithdraw(uint amt) external {
        require(deposits[msg.sender] >= amt, "Not possible");
        deposits[msg.sender] -= amt;
        withdrawalQueue[msg.sender] = withdrawalRequest(amt, block.timestamp);
    }

    function withdraw() external {
        require(withdrawalQueue[msg.sender].timestamp != 0, "Not possible");
        require(
            withdrawalQueue[msg.sender].timestamp + 1 days <= block.timestamp,
            "Withdrawal is not ready"
        );
        uint amt = withdrawalQueue[msg.sender].amount;
        delete withdrawalQueue[msg.sender];
        erc20.transfer(msg.sender, amt);
    }

    function withdrawTreasury() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not authorized to withdraw");
        uint amt = treasuryBal;
        treasuryBal = 0;
        erc20.transfer(msg.sender, amt);
    }
}
