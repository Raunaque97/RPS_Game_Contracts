pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("TestToken", "TST") {
        _mint(msg.sender, 1e21);
    }

    // create a mint function which anyone can call and get 10 TST
    function mint() public {
        _mint(msg.sender, 10e18);
    }
}
