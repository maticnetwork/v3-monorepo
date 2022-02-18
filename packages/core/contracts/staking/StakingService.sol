pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IStakingServiceReader.sol";
import "./interfaces/IDelegationReactor.sol";

contract StakingService is Initializable, IStakingServiceReader, IDelegationReactor {
  function isValidator(uint256 validatorId) external override pure returns(bool) {
    return true;
  }

  function onDelgatorAddStake(uint256 validatorId, uint256 tokenAmount) external override {

  }

  function onDelegatorRemoveStake(uint256 validatorId, uint256 tokenAmount) external override {

  }
}
