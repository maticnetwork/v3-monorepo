pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ChainConfig is Ownable {
    /// @dev How much maximum gas within a single block on Bor
    uint256 public blockGasLimit;

    /// @dev How many validator slots can be in the network
    uint256 public maxValidators;

    /// @dev Reward in MATIC tokens for all validators signed a checkpoint
    uint256 public checkpointReward;

    /// @dev How long unbonding of tokens take in seconds
    uint256 public unbondingPeriod;

    function setBlockGasLimit(uint256 _blockGasLimit) external onlyOwner {
        blockGasLimit = _blockGasLimit;
    }

    function setMaxValidators(uint256 _maxValidators) external onlyOwner {
        maxValidators = _maxValidators;
    }

    function setCheckpointReward(uint256 _checkpointReward) external onlyOwner {
        checkpointReward = _checkpointReward;
    }

    function setUnbondingPeriod(uint256 _seconds) external onlyOwner {
        unbondingPeriod = _seconds;
    }
}
