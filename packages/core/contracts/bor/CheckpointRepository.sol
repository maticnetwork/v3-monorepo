pragma solidity ^0.8.0;

import "../common/mixin/Governable.sol";
import "../common/mixin/SystemCall.sol";
import "./staking/interfaces/IRewardDistributor.sol";
import "./BorValidatorSet.sol";

contract CheckpointRepository is SystemCall, Governable {
    IRewardDistributor rewardDistributor;
    BorValidatorSet validatorSet;

    function commit(
        address[] memory _validators,
        uint256[] memory _powers,
        uint8[] memory _v,
        bytes32[] memory _r,
        bytes32[] memory _s,
        bytes32 _dataHash
    ) external systemCall {
        validatorSet.checkValidatorSignatures(
            _validators,
            _powers,
            _v,
            _r,
            _s,
            _dataHash
        );
        rewardDistributor.distributeRewardToAll(_validators);
    }
}
