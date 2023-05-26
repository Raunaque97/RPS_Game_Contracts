// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract SecurityVault is AccessControl {
    uint256 public minDeposit;
    mapping(address => uint256) public deposits;

    bytes32 public constant SLASHER_ROLE = keccak256("SLASHER"); // game organizerss who slash deposits

    constructor(uint256 _depositAmount) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        minDeposit = _depositAmount;
    }

    function deposit() external payable {
        require(msg.value >= minDeposit, "Deposit amount is incorrect");
        deposits[msg.sender] += msg.value;
    }

    function slash(address user) external {
        require(hasRole(SLASHER_ROLE, msg.sender), "Caller is not authorized to slash");
        require(deposits[user] > 0, "User has no deposit to slash");
        deposits[user] = deposits[user] >> 1; // 50% fine
    }

    function withdraw() external payable {
        uint256 d = deposits[msg.sender];
        require(d > 0, "No deposit available to withdraw");
        delete deposits[msg.sender];
        payable(msg.sender).transfer(d);
    }

    function setMinDeposit(uint256 _minDeposit) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Caller is not authorized to set min deposit"
        );
        minDeposit = _minDeposit;
    }
}
