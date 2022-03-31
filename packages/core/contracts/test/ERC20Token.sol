pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {
    constructor() ERC20("ERC20Token", "ERC20") {}

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
