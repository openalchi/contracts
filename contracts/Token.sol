// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ALCHI is ERC20, Ownable {
    uint256 private constant INITIAL_SUPPLY = 400000000 * 10 ** 18; // Adjusting for decimals

    constructor() ERC20("OPEN-ALCHI token", "ALCHI") Ownable(msg.sender) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function burn(uint256 amount) public onlyOwner {
        _burn(msg.sender, amount);
    }

}
