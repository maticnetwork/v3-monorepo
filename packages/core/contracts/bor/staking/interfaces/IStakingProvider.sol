pragma solidity ^0.8.0;

interface IStakingProvider {
    function onDelegatorStake(
        uint256 validatorId,
        uint256 tokenAmount,
        bool lockTokens
    ) external;

    function transferFunds(
        uint256 validatorId,
        uint256 amount,
        address to
    ) external returns (bool);

    function epoch() external returns (uint256);
}
