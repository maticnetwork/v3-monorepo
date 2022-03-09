pragma solidity ^0.8.0;

interface IRewardDistributor {
    function distributeRewardToAll(address[] calldata _validators) external;

    function distributeReward(address _validator, uint256 _reward) external;
}
