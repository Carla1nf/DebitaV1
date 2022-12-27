
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Ownerships is ERC1155 {
    constructor() ERC1155("") {}
    uint id = 0;

    function mint() public {
        id++;
        _mint(msg.sender, id, 1, "");
    }
}