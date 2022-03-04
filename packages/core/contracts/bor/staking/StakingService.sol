pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../../common/mixin/Lockable.sol";
import "./DelegationProxyCreator.sol";
import "./interfaces/IStakingServiceReader.sol";
import "./interfaces/IStakingProvider.sol";
import "./interfaces/IStakingLogger.sol";
import "./ValidatorSlot.sol";
import "./Delegation.sol";

contract StakingSerrvice is
    Initializable,
    OwnableUpgradeable,
    Lockable,
    IStakingServiceReader,
    IStakingProvider
{
    struct Validator {
        uint256 lockedTokens;
        Delegation delegation;
    }

    IStakingLogger logger;
    DelegationProxyCreator public delegationCreator;
    ValidatorSlot public slots;
    uint256 public currentEpoch;

    mapping(uint256 => Validator) public validators;

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

    /** VIEW METHODS */

    function isValidator(uint256 validatorId)
        external
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

    function claimValidatorSlot(address slotOwner, uint256 tokenAmount)
        external
        onlyWhenUnlocked
    {}

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
        // _transferAndTopUp(user, msg.sender, heimdallFee, amount);
        // _stakeFor(user, amount, acceptDelegation, signerPubkey);
    }

    function onDelgatorAddStake(uint256 validatorId, uint256 tokenAmount)
        external
        override
        onlyDelegation(validatorId)
    {}

    function onDelegatorRemoveStake(uint256 validatorId, uint256 tokenAmount)
        external
        override
        onlyDelegation(validatorId)
    {}

    function transferFunds(
        uint256 validatorId,
        uint256 amount,
        address to
    ) external override returns (bool) {}

    /** GOVERNANCE METHODS */
    function lock() public onlyOwner {
        _lock();
    }

    function unlock() public onlyOwner {
        _unlock();
    }
}
