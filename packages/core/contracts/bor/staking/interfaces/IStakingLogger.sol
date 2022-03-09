pragma solidity ^0.8.0;

interface IStakingLogger {
    function logValidatorSlotAcquired(
        bytes calldata _signerKey,
        uint256 _validatorId,
        uint256 _activationEpoch,
        uint256 _tokenAmount,
        uint256 _totalTokensLocked
    ) external;
}
