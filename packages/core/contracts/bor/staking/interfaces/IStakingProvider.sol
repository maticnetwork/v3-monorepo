pragma solidity ^0.8.0;

interface IStakingProvider {
    function onDelegation(
        uint256 validatorId,
        uint256 tokenAmount,
        bool lockTokens
    ) external;

    function withdrawFunds(
        uint256 validatorId,
        uint256 amount,
        address to
    ) external returns (bool);

    function depositFunds(
        uint256 validatorId,
        uint256 amount,
        address to
    ) external returns (bool);

    function epoch() external view returns (uint256);

    function withdrawDelegatorsReward(uint256 _validatorId)
        external
        returns (uint256);

    function getDelegatorsRewardAtEpoch(uint256 _validatorId, uint256 _epoch)
        external
        view
        returns (uint256);
}
