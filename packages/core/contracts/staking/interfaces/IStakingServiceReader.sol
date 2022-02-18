pragma solidity ^0.8.0;

interface IStakingServiceReader {
  function isValidator(uint256 validatorId) external returns(bool);
}
