pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../common/mixin/Lockable.sol";
import "../../common/mixin/SystemCall.sol";
import "./DelegationProxyCreator.sol";
import "./interfaces/IStakingServiceReader.sol";
import "./interfaces/IStakingProvider.sol";
import "./interfaces/IStakingLogger.sol";
import "./interfaces/IRewardDistributor.sol";
import "./ValidatorSlot.sol";
import "./Delegation.sol";
import "../ChainConfig.sol";

contract StakingSerrvice is
    Initializable,
    OwnableUpgradeable,
    Lockable,
    SystemCall,
    IStakingServiceReader,
    IStakingProvider,
    IRewardDistributor
{
    struct Validator {
        uint256 tokens;
        uint256 delegatedTokens;
        uint256 deactivationEpoch;
        uint256 initialRewardPerShare;
        uint256 reward;
        address signer;
        Delegation delegation;
    }

    struct TimelineData {
        int256 tokensLocked;
    }

    uint256 constant REWARD_PRECISION = 10**25;

    IERC20 token;
    IStakingLogger logger;
    ChainConfig config;
    DelegationProxyCreator public delegationCreator;
    ValidatorSlot public slots;
    uint256 public currentEpoch;
    uint256 public totalTokensLocked;

    mapping(address => uint256) public signerToValidatorId;

    // validatorId => validator data
    mapping(uint256 => Validator) public validators;

    // epoch => reward per share
    mapping(uint256 => uint256) public rewardPerShare;

    // epoch =>
    mapping(uint256 => TimelineData) public timeline;

    function initialize(
        DelegationProxyCreator _delegationCreator,
        IStakingLogger _logger,
        ValidatorSlot _slots
    ) external initializer {
        __Ownable_init();
        delegationCreator = _delegationCreator;
        logger = _logger;
        slots = _slots;
    }

    /** MODIFIERS */
    modifier onlyValidatorSlotOwner(uint256 validatorId) {
        require(slots.ownerOf(validatorId) == msg.sender);
        _;
    }

    modifier onlyDelegation(uint256 validatorId) {
        require(address(validators[validatorId].delegation) == msg.sender);
        _;
    }

    modifier onlySystem() {
        _;
    }

    /** VIEW METHODS */

    function isValidator(uint256 validatorId)
        public
        pure
        override
        returns (bool)
    {
        return true;
    }

    function epoch() external view override returns (uint256) {
        return currentEpoch;
    }

    /** PUBLIC METHODS */

    function distributeRewardToAll(address[] calldata _validators)
        external
        override
        onlySystem
    {
        // currently, checkpoint only works when EVERY validator signs
        // thus, simply increase reward per share accumulator

        uint256 _currentEpoch = currentEpoch;
        _currentEpoch++;

        rewardPerShare[_currentEpoch] =
            (config.checkpointReward() * REWARD_PRECISION) /
            totalTokensLocked;

        _advanceTimeline(_currentEpoch);
    }

    /// @dev This methods increase reward for a single validator. Called after each mined block on Bor.
    /// @param _validatorSigner address of the signer used to sign a block.
    /// @param _reward in wrapped MATIC tokens
    function distributeReward(address _validatorSigner, uint256 _reward)
        external
        override
        onlySystem
    {
        uint256 validatorId = signerToValidatorId[_validatorSigner];
        require(isValidator(validatorId));

        // increase total reward
        validators[validatorId].reward += _reward;
    }

    function claimValidatorSlot(
        address _slotOwner,
        uint256 _tokenAmount,
        bytes calldata _signerPubkey
    ) external onlyWhenUnlocked returns (uint256) {
        address signer = _getSignerAddress(_signerPubkey);
        uint256 _currentEpoch = currentEpoch;
        uint256 validatorId = slots.mint(_slotOwner);

        uint256 newTotalStaked = totalTokensLocked + _tokenAmount;
        totalTokensLocked = newTotalStaked;

        validators[validatorId] = Validator({
            tokens: _tokenAmount,
            deactivationEpoch: 0,
            signer: signer,
            delegation: Delegation(delegationCreator.create(validatorId)),
            reward: 0,
            delegatedTokens: 0,
            initialRewardPerShare: _currentRewardPerShare()
        });

        signerToValidatorId[signer] = validatorId;
        _modifyTimeline(_currentEpoch + 1, int256(_tokenAmount));
        logger.logValidatorSlotAcquired(
            _signerPubkey,
            validatorId,
            _currentEpoch,
            _tokenAmount,
            newTotalStaked
        );

        return validatorId;
    }

    /// @notice Remove tokens from the stake
    function unstake(uint256 validatorId, uint256 tokenAmount)
        external
        onlyValidatorSlotOwner(validatorId)
    {}

    /// @notice Stake some tokens or available rewards
    function stake(
        uint256 validatorId,
        uint256 tokenAmount,
        bool stakeRewards
    ) external onlyValidatorSlotOwner(validatorId) {
        // require(currentValidatorSetSize() < validatorThreshold, "no more slots");
        // require(amount >= minDeposit, "not enough deposit");
        token.transferFrom(msg.sender, address(this), tokenAmount);
    }

    function onDelegatorStake(
        uint256 validatorId,
        uint256 tokenAmount,
        bool lockTokens
    ) external override onlyDelegation(validatorId) {
        uint256 deactivationEpoch = validators[validatorId].deactivationEpoch;
        if (deactivationEpoch == 0) {
            // modify timeline only if validator didn't unstake
            // updateTimeline(tokenAmount, 0, 0);
        } else if (deactivationEpoch > currentEpoch) {
            // validator just unstaked, need to wait till next checkpoint
            revert("unstaking");
        }

        if (lockTokens) {
            validators[validatorId].delegatedTokens += tokenAmount;
            totalTokensLocked += tokenAmount;
        } else {
            validators[validatorId].delegatedTokens -= tokenAmount;
            totalTokensLocked -= tokenAmount;
        }
    }

    function transferFunds(
        uint256 validatorId,
        uint256 amount,
        address to
    ) external override onlyDelegation(validatorId) returns (bool) {
        return token.transfer(to, amount);
    }

    /** GOVERNANCE METHODS */
    function lock() public onlyOwner {
        _lock();
    }

    function unlock() public onlyOwner {
        _unlock();
    }

    /** PRIVATE METHODS */
    function _currentRewardPerShare() private view returns (uint256) {
        return rewardPerShare[currentEpoch];
    }

    function _getSignerAddress(bytes memory _publicKey)
        private
        view
        returns (address)
    {
        require(_publicKey.length == 64, "invalid public key");
        address signer = address(uint160(uint256(keccak256(_publicKey))));
        require(
            signer != address(0) && signerToValidatorId[signer] == 0,
            "invalid signer"
        );
        return signer;
    }

    function _modifyTimeline(uint256 _targetEpoch, int256 tokenDelta) private {
        timeline[_targetEpoch].tokensLocked += tokenDelta;
    }

    function _advanceTimeline(uint256 _currentEpoch) private {
        int256 tokensLocked = timeline[_currentEpoch].tokensLocked;
        if (tokensLocked == 0) {
            return;
        }

        if (tokensLocked > 0) {
            totalTokensLocked += uint256(tokensLocked);
        } else if (tokensLocked < 0) {
            totalTokensLocked -= uint256(-tokensLocked);
        }

        delete timeline[_currentEpoch];
    }
}
