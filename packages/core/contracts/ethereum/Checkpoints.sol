pragma solidity ^0.8.0;

import "../common/mixin/Governable.sol";
import "./EthereumValidatorSet.sol";

contract Checkpoints is Governable {
    /// @dev Explain to a developer any extra details
    /// @param proposer Address of the checkpoint proposer
    /// @param checkpointId Id of the checkpoint
    /// @param start Start of the block range in the checkpoint
    /// @param end End of the block range in the checkpoint
    /// @param root Root hash of the block range
    event CheckpointSubmitted(
        address indexed proposer,
        uint256 indexed checkpointId,
        uint256 start,
        uint256 end,
        bytes32 root
    );

    struct Checkpoint {
        bytes32 root;
        uint256 start;
        uint256 end;
        uint256 createdAt;
        address proposer;
    }

    uint256 public constant CHAIN_ID = 15001;
    uint256 public checkpointId;
    EthereumValidatorSet public validatorSet;

    mapping(uint256 => Checkpoint) public checkpoints;

    function submit(
        bytes memory data,
        address[] memory _validators,
        uint256[] memory _powers,
        bytes32 _dataHash,
        uint8[] memory _v,
        bytes32[] memory _r,
        bytes32[] memory _s
    ) external {
        validatorSet.checkValidatorSignatures(
            _validators,
            _powers,
            _v,
            _r,
            _s,
            _dataHash
        );

        (
            address proposer,
            uint256 start,
            uint256 end,
            bytes32 rootHash,
            bytes32 accountHash,
            uint256 chainId
        ) = abi.decode(
                data,
                (address, uint256, uint256, bytes32, bytes32, uint256)
            );
        require(CHAIN_ID == chainId, "Invalid bor chain id");

        _validateAndSubmitCheckpoint(proposer, start, end, rootHash);
    }

    /** PRIVATE METHODS */

    function _validateAndSubmitCheckpoint(
        address proposer,
        uint256 start,
        uint256 end,
        bytes32 rootHash
    ) private returns (bool) {
        uint256 startBorBlock;
        uint256 _checkpointId = checkpointId;

        if (_checkpointId != 0) {
            // not a first checkpoint,
            startBorBlock = checkpoints[_checkpointId].end + 1;
        }
        if (startBorBlock != start) {
            revert("incorrect start block");
        }

        Checkpoint memory checkpoint = Checkpoint({
            root: rootHash,
            start: startBorBlock,
            end: end,
            createdAt: block.timestamp,
            proposer: proposer
        });

        checkpoints[_checkpointId] = checkpoint;

        emit CheckpointSubmitted(proposer, _checkpointId, start, end, rootHash);

        checkpointId = _checkpointId + 1;
    }
}
