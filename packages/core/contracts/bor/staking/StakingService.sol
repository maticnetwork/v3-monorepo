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
import "hardhat/console.sol";

contract StakingService is
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

    // epoch => reward per share for all validators
    mapping(uint256 => uint256) public sharedRewards;

    // validator id => ( epoch => reward per share )
    mapping(uint256 => mapping(uint256 => uint256)) public validatorRewards;

    // epoch => total locked tokens
    mapping(uint256 => uint256) public totalLockedTokens;

    function initialize(
        DelegationProxyCreator _delegationCreator,
        IStakingLogger _logger,
        ValidatorSlot _slots,
        IERC20 _token,
        ChainConfig _config
    ) external initializer {
        __Ownable_init();
        delegationCreator = _delegationCreator;
        logger = _logger;
        slots = _slots;
        token = _token;
        config = _config;
    }

    /** MODIFIERS */
    modifier onlyValidatorSlotOwner(uint256 _validatorId) {
        _assertOnlyValidator(_validatorId);
        _;
    }

    function _assertOnlyValidator(uint256 _validatorId) private {
        require(slots.ownerOf(_validatorId) == msg.sender, "not validator");
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
        currentEpoch = _currentEpoch;

        sharedRewards[_currentEpoch] =
            sharedRewards[_currentEpoch - 1] +
            ((config.checkpointReward() * REWARD_PRECISION) /
                getTotalLockedTokens());

        totalLockedTokens[_currentEpoch + 1] = totalLockedTokens[_currentEpoch];

        delete totalLockedTokens[_currentEpoch - 1];

        console.log('getTotalLockedTokens', getTotalLockedTokens());
        console.log('reward', (config.checkpointReward() * REWARD_PRECISION));

        // TODO clean up validatorTokens and delegatedTokens for each validator
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
        validatorRewards[validatorId][currentEpoch] += (_reward * REWARD_PRECISION / getTotalLockedTokens());

        console.log('currentEpoch', currentEpoch);
        console.log('distribute reward', validatorRewards[validatorId][currentEpoch]);
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
        IStakingLogger _logger = logger;

        validators[validatorId] = Validator({
            deactivationEpoch: 0,
            signer: signer,
            delegation: Delegation(
                delegationCreator.create(validatorId, address(_logger))
            ),
            rewardEpoch: _currentEpoch + 1,
            commissionRate: 0,
            accumulatedReward: 0,
            accumulatedDelegatorsReward: 0,
            lastStakeEpoch: _currentEpoch + 1
        });

        signerToValidatorId[signer] = validatorId;
        _setValidatorTokens(validatorId, _currentEpoch + 1, _tokenAmount);
        _setTotalLockedTokens(_currentEpoch + 1, _tokenAmount, true);

        _logger.logValidatorSlotAcquired(
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
        uint256 _validatorId,
        uint256 _tokenAmount,
        bool _stakeRewards
    ) external onlyValidatorSlotOwner(_validatorId) {
        // require(currentValidatorSetSize() < validatorThreshold, "no more slots");
        // require(amount >= minDeposit, "not enough deposit");

        token.transferFrom(msg.sender, address(this), _tokenAmount);

        uint256 _currentEpoch = currentEpoch;
        (, uint256 _lockedTokens) = _getAndCommitValidatorTokens(_validatorId, _currentEpoch + 1);
        console.log('stake: _lockedTokens', _lockedTokens);
        _lockedTokens += _tokenAmount;

        // update rewards, because stake is changing
        _updateRewardsAndCommit(_validatorId);

        if (_stakeRewards) {
            // collect accumulated rewards and stake
            uint256 reward = _collectReward(_validatorId);
            console.log('collect reward', reward);
            _tokenAmount += reward;
        }

        _setValidatorTokens(_validatorId, _currentEpoch + 1, _lockedTokens);
        _setTotalLockedTokens(
            _currentEpoch + 1,
            _tokenAmount,
            true
        );
    }

    function collectReward(uint256 _validatorId)
        external
        onlyValidatorSlotOwner(_validatorId)
    {
        _updateRewardsAndCommit(_validatorId);
        uint256 reward = _collectReward(_validatorId);
        require(token.transfer(msg.sender, reward));
    }

    function onDelegation(
        uint256 _validatorId,
        uint256 _tokenAmount,
        bool _lockTokens
    ) external override onlyDelegation(_validatorId) {
        uint256 _currentEpoch = currentEpoch;
        // delay tokens arrival by 1 epoch
        _currentEpoch++;

        (uint256 _futureDelegatedTokens, ) = _getAndCommitValidatorTokens(_validatorId, _currentEpoch);

        if (_lockTokens) {
            delegatedTokens[_validatorId][_currentEpoch] =
                _futureDelegatedTokens +
                _tokenAmount;
            _setTotalLockedTokens(_currentEpoch, _tokenAmount, true);
        } else {
            delegatedTokens[_validatorId][_currentEpoch] =
                _futureDelegatedTokens -
                _tokenAmount;
            _setTotalLockedTokens(_currentEpoch, _tokenAmount, false);
        }
    }

    /** Delegation utility methods */

    function getDelegatorsRewardAtEpoch(uint256 _validatorId, uint256 _epoch)
        external
        view
        override
        returns (uint256)
    {
        uint256 initialRewardPerShare = sharedRewards[_epoch];
        initialRewardPerShare =
            validatorRewards[_validatorId][_epoch] +
            initialRewardPerShare;

        uint256 nextEpoch = _epoch + 1;
        uint256 currentRewardPerShare = sharedRewards[nextEpoch];
        currentRewardPerShare =
            validatorRewards[_validatorId][nextEpoch] +
            currentRewardPerShare;

        uint256 reward = _calculateReward(
            delegatedTokens[_validatorId][_epoch],
            initialRewardPerShare,
            currentRewardPerShare
        );

        uint256 _delegatedTokens = delegatedTokens[_validatorId][nextEpoch];
        uint256 totalTokens = validatorTokens[_validatorId][nextEpoch] +
            _delegatedTokens;

        (, uint256 delegatorsReward) = _getValidatorAndDelegationReward(
            _validatorId,
            _delegatedTokens,
            reward,
            totalTokens
        );

        return delegatorsReward;
    }

    function withdrawDelegatorsReward(uint256 _validatorId)
        external
        override
        onlyDelegation(_validatorId)
        returns (uint256)
    {
        _updateRewardsAndCommit(_validatorId);

        uint256 totalReward = validators[_validatorId]
            .accumulatedDelegatorsReward;
        validators[_validatorId].accumulatedDelegatorsReward = 0;
        return totalReward;
    }

    function withdrawFunds(
        uint256 _validatorId,
        uint256 _amount,
        address _to
    ) external override onlyDelegation(_validatorId) returns (bool) {
        return token.transfer(_to, _amount);
    }

    function depositFunds(
        uint256 _validatorId,
        uint256 _amount,
        address _from
    ) external override onlyDelegation(_validatorId) returns (bool) {
        return token.transferFrom(_from, address(this), _amount);
    }

    /** GOVERNANCE METHODS */
    function lock() public onlyOwner {
        _lock();
    }

    function unlock() public onlyOwner {
        _unlock();
    }

    /** PRIVATE METHODS */

    function _getAndCommitValidatorTokens(uint256 _validatorId, uint256 _currentEpoch) private returns(uint256, uint256) {
        uint256 _lastStakeEpoch = validators[_validatorId].lastStakeEpoch;
        bool updateStakeEpoch = false;
        
        uint256 _delegatedTokens = delegatedTokens[_validatorId][_currentEpoch];
        if (_delegatedTokens == 0) {
            updateStakeEpoch = true;
            _delegatedTokens = delegatedTokens[
                _validatorId
            ][_lastStakeEpoch];
            delegatedTokens[_validatorId][_currentEpoch] = _delegatedTokens;
        }

        uint256 _validatorTokens = validatorTokens[_validatorId][_currentEpoch];
        if (_validatorTokens == 0) {
            updateStakeEpoch = true;
            _validatorTokens = validatorTokens[_validatorId][_lastStakeEpoch];
            validatorTokens[_validatorId][_currentEpoch] = _validatorTokens;
        }

        if (updateStakeEpoch) {
            validators[_validatorId].lastStakeEpoch = _currentEpoch;
        }

        return (_delegatedTokens, _validatorTokens);
    }

    function _setTotalLockedTokens(
        uint256 _nextEpoch,
        uint256 _tokens,
        bool _add
    ) private {
        #if hardhat 
        assert(_nextEpoch == currentEpoch + 1);
        #endif

        if (_add) {
            totalLockedTokens[_nextEpoch] += _tokens;
        } else {
            totalLockedTokens[_nextEpoch] -= _tokens;
        }
    }

    function _updateRewardsAndCommit(uint256 _validatorId) private {
        uint256 rewardEpoch = validators[_validatorId].rewardEpoch;
        uint256 _currentEpoch = currentEpoch;

        console.log('_updateRewardsAndCommit');

        // attempt to save gas in case if rewards were updated previosuly
        if (rewardEpoch < _currentEpoch) {
            console.log('_updateRewardsAndCommit: update reward');
            // combine per validator rewards with shared rewards
            uint256 initialRewardPerShare = sharedRewards[rewardEpoch];
            initialRewardPerShare =
                validatorRewards[_validatorId][rewardEpoch] +
                initialRewardPerShare;

            uint256 currentRewardPerShare = sharedRewards[_currentEpoch];
            currentRewardPerShare =
                validatorRewards[_validatorId][_currentEpoch] +
                currentRewardPerShare;

            uint256 stakeEpoch = validators[_validatorId].lastStakeEpoch;
            // get tokens
            uint256 _validatorTokens = validatorTokens[_validatorId][
                stakeEpoch
            ];
            uint256 _delegatedToken = delegatedTokens[_validatorId][
                stakeEpoch
            ];

            console.log('_updateRewardsAndCommit: _validatorTokens', _validatorTokens);
            console.log('_updateRewardsAndCommit: initialRewardPerShare', initialRewardPerShare);
            console.log('_updateRewardsAndCommit: currentRewardPerShare', currentRewardPerShare);

            if (_delegatedToken > 0) {
                uint256 totalTokens = _delegatedToken + _validatorTokens;

                _increaseValidatorRewardWithDelegation(
                    _validatorId,
                    _validatorTokens,
                    _delegatedToken,
                    _calculateReward(
                        totalTokens,
                        currentRewardPerShare,
                        initialRewardPerShare
                    )
                );
            } else {
                validators[_validatorId].accumulatedReward += _calculateReward(
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

    function _setValidatorTokens(
        uint256 _validatorId,
        uint256 _epoch,
        uint256 _amount
    ) private {
        validatorTokens[_validatorId][_epoch] = _amount;
    }

    function _collectReward(uint256 _validatorId) private returns (uint256) {
        uint256 reward = validators[_validatorId].accumulatedReward;
        validators[_validatorId].accumulatedReward = 0;
        return reward;
    }
}
