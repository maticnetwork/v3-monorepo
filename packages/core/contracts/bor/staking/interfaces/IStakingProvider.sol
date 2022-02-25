pragma solidity ^0.8.0;

interface IStakingProvider {
  function onDelgatorAddStake(uint256 validatorId, uint256 tokenAmount) external;
  function onDelegatorRemoveStake(uint256 validatorId, uint256 tokenAmount) external;
  function transferFunds(uint256 validatorId, uint256 amount, address to) external returns(bool);
  function epoch() external returns(uint256);
}
