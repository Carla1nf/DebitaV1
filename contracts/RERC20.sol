
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DebitaERC20 is ERC20 {

constructor() ERC20("DEBITA TOKEN", "Token"){

}

function mint(uint amount) public {
    _mint(msg.sender, amount);
}

}