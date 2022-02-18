pragma solidity ^0.8.0;

interface IDelegationReactor {
  function onDelgatorAddStake(uint256 validatorId, uint256 tokenAmount) external;
  function onDelegatorRemoveStake(uint256 validatorId, uint256 tokenAmount) external;
}
