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
        uint256 deactivationEpoch;
        uint256 rewardEpoch;
        uint256 lastStakeEpoch;
        uint256 accumulatedReward;
        uint256 accumulatedDelegatorsReward;
        uint256 commissionRate;
        address signer;
        Delegation delegation;
    }

    uint256 constant REWARD_PRECISION = 10**25;
    uint256 constant MAX_COMMISION_RATE = 10000;

    IERC20 token;
    IStakingLogger logger;
    ChainConfig config;
    DelegationProxyCreator delegationCreator;
    ValidatorSlot slots;
    uint256 currentEpoch;

    mapping(address => uint256) public signerToValidatorId;

    // validatorId => validator data
    mapping(uint256 => Validator) public validators;

    // validator id => ( epoch => validator staked tokens )
    mapping(uint256 => mapping(uint256 => uint256)) public validatorTokens;

    // validator id => ( epoch => delegators staked tokens )
    mapping(uint256 => mapping(uint256 => uint256)) public delegatedTokens;

    // epoch => reward per share
    mapping(uint256 => uint256) public sharedRewards;

    // validator id => ( epoch => reward per share )
    mapping(uint256 => mapping(uint256 => uint256)) public validatorRewards;

    // epoch => total locked tokens
    mapping(uint256 => uint256) public totalLockedTokens;

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

    modifier onlyCheckpoint() {
        _;
    }

    /** VIEW METHODS */
    function getTotalLockedTokens() public view returns (uint256) {
        return totalLockedTokens[currentEpoch];
    }

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
        onlyCheckpoint
    {
        // currently, checkpoint only works when EVERY validator signs
        // thus, simply increase reward per share accumulator

        uint256 _currentEpoch = currentEpoch;
        _currentEpoch++;

        sharedRewards[_currentEpoch] =
            sharedRewards[_currentEpoch - 1] +
            ((config.checkpointReward() * REWARD_PRECISION) /
                getTotalLockedTokens());

        delete totalLockedTokens[_currentEpoch - 1];
        currentEpoch = _currentEpoch;
    }

    /// @dev This methods increase reward for a single validator. Called after each mined block on Bor.
    /// @param _validatorSigner address of the signer used to sign a block.
    /// @param _reward in wrapped MATIC tokens
    function distributeReward(address _validatorSigner, uint256 _reward)
        external
        override
        systemCall
    {
        uint256 validatorId = signerToValidatorId[_validatorSigner];
        require(isValidator(validatorId));

        // increase per validator reward
        validatorRewards[validatorId][currentEpoch] += _reward;
    }

    function claimValidatorSlot(
        address _slotOwner,
        uint256 _tokenAmount,
        bytes calldata _signerPubkey
    ) external onlyWhenUnlocked returns (uint256) {
        address signer = _getSignerAddress(_signerPubkey);
        uint256 _currentEpoch = currentEpoch;
        uint256 validatorId = slots.mint(_slotOwner);

        uint256 newTotalStaked = getTotalLockedTokens() + _tokenAmount;

        validators[validatorId] = Validator({
            deactivationEpoch: 0,
            signer: signer,
            delegation: Delegation(delegationCreator.create(validatorId)),
            rewardEpoch: _currentEpoch + 1,
            commissionRate: 0,
            accumulatedReward: 0,
            accumulatedDelegatorsReward: 0,
            lastStakeEpoch: _currentEpoch
        });

        signerToValidatorId[signer] = validatorId;
        _setTotalLockedTokens(_currentEpoch + 1, _tokenAmount, true);

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
    {
        _setTotalLockedTokens(currentEpoch + 1, tokenAmount, false);
    }

    /// @notice Stake some tokens or available rewards
    function stake(
        uint256 validatorId,
        uint256 tokenAmount,
        bool stakeRewards
    ) external onlyValidatorSlotOwner(validatorId) {
        // require(currentValidatorSetSize() < validatorThreshold, "no more slots");
        // require(amount >= minDeposit, "not enough deposit");
        token.transferFrom(msg.sender, address(this), tokenAmount);
        _setTotalLockedTokens(currentEpoch + 1, tokenAmount, true);
    }

    function onDelegation(
        uint256 _validatorId,
        uint256 _tokenAmount,
        bool _lockTokens
    ) external override onlyDelegation(_validatorId) {
        uint256 _currentEpoch = currentEpoch;
        // delay tokens arrival by 1 epoch
        _currentEpoch++;

        uint256 _currentDelegatedTokens = delegatedTokens[_validatorId][
            _currentEpoch
        ];
        if (_currentDelegatedTokens == 0) {
            // if it's a first time stake, move values from previous stake epoch
            uint256 _lastStakeEpoch = validators[_validatorId].lastStakeEpoch;
            delegatedTokens[_validatorId][_currentEpoch] = delegatedTokens[
                _validatorId
            ][_lastStakeEpoch];

            validators[_validatorId].lastStakeEpoch = _currentEpoch;
        }

        if (_lockTokens) {
            delegatedTokens[_validatorId][_currentEpoch] =
                _currentDelegatedTokens +
                _tokenAmount;
        } else {
            delegatedTokens[_validatorId][_currentEpoch] =
                _currentDelegatedTokens -
                _tokenAmount;
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

    function withdrawDelegatorsReward(uint256 _validatorId)
        public
        onlyDelegation(_validatorId)
        returns (uint256)
    {
        _updateRewardsAndCommit(_validatorId);

        uint256 tokens = validators[_validatorId].accumulatedDelegatorsReward;
        validators[_validatorId].accumulatedDelegatorsReward = 0;
        return tokens;
    }

    /** PRIVATE METHODS */

    function _setTotalLockedTokens(
        uint256 _epoch,
        uint256 tokens,
        bool add
    ) private {
        if (add) {
            totalLockedTokens[_epoch] += tokens;
        } else {
            totalLockedTokens[_epoch] -= tokens;
        }
    }

    function _updateRewardsAndCommit(uint256 _validatorId) private {
        uint256 rewardEpoch = validators[_validatorId].rewardEpoch;
        uint256 _currentEpoch = currentEpoch;

        // attempt to save gas in case if rewards were updated previosuly
        if (rewardEpoch < _currentEpoch) {
            uint256 initialRewardPerShare = sharedRewards[rewardEpoch];
            uint256 currentRewardPerShare = sharedRewards[_currentEpoch];

            uint256 _validatorTokens = validatorTokens[_validatorId][
                _currentEpoch
            ];
            uint256 _delegatedToken = delegatedTokens[_validatorId][
                _currentEpoch
            ];

            if (_delegatedToken > 0) {
                uint256 totalTokens = _delegatedToken + _validatorTokens;
                initialRewardPerShare =
                    validatorRewards[_validatorId][rewardEpoch] +
                    initialRewardPerShare;
                currentRewardPerShare =
                    validatorRewards[_validatorId][_currentEpoch] +
                    currentRewardPerShare;

                _increaseValidatorRewardWithDelegation(
                    _validatorId,
                    _validatorTokens,
                    _delegatedToken,
                    _calculateReward(
                        _validatorId,
                        totalTokens,
                        currentRewardPerShare,
                        initialRewardPerShare
                    )
                );
            } else {
                validators[_validatorId].accumulatedReward += _calculateReward(
                    _validatorId,
                    _validatorTokens,
                    currentRewardPerShare,
                    initialRewardPerShare
                );
            }

            validators[_validatorId].rewardEpoch = _currentEpoch;
        }
    }

    function _getValidatorAndDelegationReward(
        uint256 _validatorId,
        uint256 _validatorTokens,
        uint256 _totalTokens,
        uint256 _reward
    ) internal view returns (uint256, uint256) {
        if (_totalTokens == 0) {
            return (0, 0);
        }

        uint256 validatorReward = (_validatorTokens * _reward) / _totalTokens;

        // add validator commission from delegation reward
        uint256 commissionRate = validators[_validatorId].commissionRate;
        if (commissionRate > 0) {
            validatorReward =
                ((_reward - validatorReward) * commissionRate) /
                MAX_COMMISION_RATE;
        }

        uint256 delegatorsReward = _reward - validatorReward;
        return (validatorReward, delegatorsReward);
    }

    function _increaseValidatorRewardWithDelegation(
        uint256 _validatorId,
        uint256 _validatorTokens,
        uint256 _delegatedTokens,
        uint256 _reward
    ) private {
        uint256 totalTokens = _validatorTokens + _validatorTokens;
        (
            uint256 validatorReward,
            uint256 delegatorsReward
        ) = _getValidatorAndDelegationReward(
                _validatorId,
                _validatorTokens,
                _reward,
                totalTokens
            );

        if (delegatorsReward > 0) {
            validators[_validatorId]
                .accumulatedDelegatorsReward += delegatorsReward;
        }

        if (validatorReward > 0) {
            validators[_validatorId].accumulatedReward += validatorReward;
        }
    }

    function _calculateReward(
        uint256 validatorId,
        uint256 stake,
        uint256 currentRewardPerStake,
        uint256 initialRewardPerStake
    ) private pure returns (uint256) {
        uint256 eligibleReward = currentRewardPerStake - initialRewardPerStake;
        return (eligibleReward * stake) / REWARD_PRECISION;
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
}
