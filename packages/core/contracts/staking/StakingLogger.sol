pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IStakingServiceReader.sol";
import "./interfaces/IDelegationLogger.sol";

contract StakingLogger is Initializable, IDelegationLogger {
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
    /// @param signer Signer address used to sign checkpoints
    /// @param signerPubkey Raw signer public key used to sign checkpoints
    /// @param validatorId ID of the validator slot
    /// @param activationEpoch Epoch when validator starts to sign checkpoints
    /// @param tokenAmount Amount of tokens used to acquire validator slot
    /// @param networkTokenAmount Total staked tokens in the network at the moment of acquisition
    /// @param nonce Event nonce
    event ValidatorJoined(
        address indexed signer,
        bytes signerPubkey,
        uint256 indexed validatorId,
        uint256 indexed activationEpoch,
        uint256 tokenAmount,
        uint256 networkTokenAmount,
        uint256 nonce
    );

    function logValidatorSlotAcquired(uint256 validatorId)
        external
        onlyStakingService
    {}
    
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
    event DelegatorAddStake(
        uint256 indexed validatorId,
        address indexed user,
        uint256 indexed totalStaked
    );

    /// @dev Indicate to consensus module that delegator removed his tokens from staking
    event DelegatorRemoveStake(
        uint256 indexed validatorId,
        address indexed user,
        uint256 amount
    );
}
