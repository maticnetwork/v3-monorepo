pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ChainConfig is Ownable {
    uint256 public blockGasLimit;
    uint256 public maxValidators;

    function setBlockGasLimit(uint256 _blockGasLimit) external onlyOwner {
        blockGasLimit = _blockGasLimit;
    }

    function setMaxValidators(uint256 _maxValidators) external onlyOwner {
        maxValidators = _maxValidators;
    }
}
