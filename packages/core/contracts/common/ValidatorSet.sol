pragma solidity ^0.8.0;

import "./mixin/Governable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract ValidatorSet is Governable {
    bytes32 validatorSetHash;
    uint256 powerThreshold;

    /** View functions */
    function isValidatorSetCorrect(
        address[] memory _validators,
        uint256[] memory _powers,
        uint256 _validatorSetNonce
    ) public view returns (bool) {
        return
            getValidatorSetHash(
                _validators,
                _powers,
                _validatorSetNonce,
                powerThreshold
            ) == validatorSetHash;
    }

    /** Public Methods */

    function updateValidatorSet(
        address[] memory _newValidators,
        uint256[] memory _newPowers,
        uint256 _newValidatorSetNonce,
        address[] memory _validators,
        uint256[] memory _powers,
        uint256 _validatorSetNonce,
        uint8[] memory _v,
        bytes32[] memory _r,
        bytes32[] memory _s,
        uint256 _powerThreshold
    ) external {
        require(
            _newValidatorSetNonce == _validatorSetNonce + 1,
            "incorrect nonce"
        );

        isValidatorSetCorrect(_validators, _powers, _validatorSetNonce);

        bytes32 newValidatorSetHash = getValidatorSetHash(
            _newValidators,
            _newPowers,
            _newValidatorSetNonce,
            _powerThreshold
        );

        _checkValidatorSignatures(
            _validators,
            _powers,
            _v,
            _r,
            _s,
            newValidatorSetHash,
            _powerThreshold
        );

        validatorSetHash = newValidatorSetHash;
        powerThreshold = _powerThreshold;
    }

    function checkValidatorSignatures(
        address[] memory _currentValidators,
        uint256[] memory _currentPowers,
        // The current validator's signatures
        uint8[] memory _v,
        bytes32[] memory _r,
        bytes32[] memory _s,
        // This is what we are checking they have signed
        bytes32 _dataHash
    ) external view {
        _checkValidatorSignatures(
            _currentValidators,
            _currentPowers,
            _v,
            _r,
            _s,
            _dataHash,
            powerThreshold
        );
    }

    /** Private methods */

    function _checkValidatorSignatures(
        // The current validator set and their powers
        address[] memory _currentValidators,
        uint256[] memory _currentPowers,
        // The current validator's signatures
        uint8[] memory _v,
        bytes32[] memory _r,
        bytes32[] memory _s,
        // This is what we are checking they have signed
        bytes32 _dataHash,
        uint256 _powerThreshold
    ) private pure {
        uint256 cumulativePower = 0;
        for (uint256 i = 0; i < _currentValidators.length; i++) {
            // Check that the current validator has signed off on the hash
            (address signer, ) = ECDSA.tryRecover(
                _dataHash,
                _v[i],
                _r[i],
                _s[i]
            );
            require(
                signer == _currentValidators[i],
                "signature does not match"
            );
            // Sum up cumulative power
            cumulativePower = cumulativePower + _currentPowers[i];
            // Break early to avoid wasting gas
            if (cumulativePower > _powerThreshold) {
                break;
            }
        }
        // Check that there was enough power
        require(cumulativePower > _powerThreshold, "not have enough power");
    }

    function getValidatorSetHash(
        address[] memory _validators,
        uint256[] memory _powers,
        uint256 _validatorSetNonce,
        uint256 _powerThreshold
    ) private pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    0x636865636b706f696e7400000000000000000000000000000000000000000000,
                    _validatorSetNonce,
                    _validators,
                    _powers,
                    _powerThreshold
                )
            );
    }
}
