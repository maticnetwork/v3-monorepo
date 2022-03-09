pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IStakingServiceReader.sol";
import "./interfaces/IDelegationLogger.sol";
import "./interfaces/IStakingLogger.sol";

contract StakingLogger is Initializable, IDelegationLogger, IStakingLogger {
    mapping(uint256 => uint256) public validatorNonce;
    IStakingServiceReader public stakingService;

    modifier onlyStakingService() {
        require(address(stakingService) == msg.sender);
        _;
    }

    modifier onlyDelegation(uint256 validatorId) {
        require(stakingService.isValidator(validatorId));
        _;
    }

    function initialize(IStakingServiceReader _stakingService)
        external
        initializer
    {
        stakingService = _stakingService;
    }

    /// @dev Indicate to consensus module that new validator joined
    /// @param signerKey Raw signer public key used to sign checkpoints
    /// @param validatorId ID of the validator slot
    /// @param activationEpoch Epoch when validator starts to sign checkpoints
    /// @param tokenAmount Amount of tokens used to acquire validator slot
    /// @param totalTokensLocked Total staked tokens in the network at the moment of acquisition
    /// @param nonce Event nonce
    event ValidatorJoined(
        bytes signerKey,
        uint256 indexed validatorId,
        uint256 indexed activationEpoch,
        uint256 tokenAmount,
        uint256 totalTokensLocked,
        uint256 nonce
    );

    function logValidatorSlotAcquired(
        bytes calldata _signerKey,
        uint256 _validatorId,
        uint256 _activationEpoch,
        uint256 _tokenAmount,
        uint256 _totalTokensLocked
    ) external override onlyStakingService {
        emit ValidatorJoined(
            _signerKey,
            _validatorId,
            _activationEpoch,
            _tokenAmount,
            _totalTokensLocked,
            _acquireNonce(_validatorId)
        );
    }

    /// @dev Indicate to consensus module that validator collected his stake
    event ValidatorStakeCollected(
        address indexed user,
        uint256 indexed validatorId,
        uint256 stakeAmount,
        uint256 networkStakeAmount
    );

    /// @dev Indicate to consensus module that validator left the network
    event ValidatorLeft(
        address indexed user,
        uint256 indexed validatorId,
        uint256 nonce,
        uint256 deactivationEpoch,
        uint256 indexed amount
    );

    /// @dev Indicate to consensus module that validator checkpoint signer address has changed
    event ValidatorSignerUpdate(
        uint256 indexed validatorId,
        uint256 nonce,
        address indexed oldSigner,
        address indexed newSigner,
        bytes signerPubkey
    );

    /// @dev Indicate to consensus module that delegator staked tokens for validator
    event DelegatorStake(
        uint256 indexed validatorId,
        address indexed user,
        uint256 indexed totalStaked
    );

    /// @dev Indicate to consensus module that delegator removed his tokens from staking
    event DelegatorUnstake(
        uint256 indexed validatorId,
        address indexed user,
        uint256 amount
    );

    function _acquireNonce(uint256 _validatorId) private returns (uint256) {
        uint256 nonce = validatorNonce[_validatorId];
        nonce++;
        validatorNonce[_validatorId] = nonce;
        return nonce;
    }
}
