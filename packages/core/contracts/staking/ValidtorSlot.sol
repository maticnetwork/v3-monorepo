pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract ValidatorSlot is ERC721 {
    constructor() ERC721("", "") {}

    function name() public view virtual override returns (string memory) {
        return "";
    }
}
