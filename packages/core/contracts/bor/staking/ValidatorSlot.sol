pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ValidatorSlot is ERC721, Ownable {
    uint256 private slotId;

    constructor() ERC721("Validator Slot", "VS") {}

    function mint(address to) external onlyOwner {
        slotId += 1;
        _mint(to, slotId);
    }

    function burn(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
    }
}
