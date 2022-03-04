pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/IDelegationLogger.sol";
import "./interfaces/IStakingProvider.sol";

contract Delegation is ERC20Upgradeable {
    struct DelegatorUnbond {
        uint256 shares;
        uint256 withdrawEpoch;
    }

    uint256 constant EXCHANGE_RATE_PRECISION = 10**29;
    uint256 constant REWARD_PRECISION = 10**25;

    IDelegationLogger public logger;
    IStakingProvider public stakingProvider;

    uint256 public validatorId;
    uint256 public tokensLocked;

    mapping(address => uint256) public initalRewardPerShare;
    mapping(address => mapping(uint256 => DelegatorUnbond)) public unbonds;
    mapping(address => uint256) public unbondNonces;

    // track how many tokens per share to distribute
    uint256 public rewardPerShare;
    // keeps track of currently withdrwawn but not yet claimed tokens
    uint256 public withdrawalTokenPool;
    // keeps track of withdrawan but not yet claimed shares in case of slashing
    uint256 public withdrawalSharesPool;

    function initialize(
        uint256 _validatorId,
        IStakingProvider _stakingProvider,
        IDelegationLogger _logger
    ) external initializer {
        // give shares meaningful name
        string memory name = string(
            abi.encodePacked("Delegation Shares ", _validatorId)
        );
        string memory symbol = string(abi.encodePacked("DS", _validatorId));
        __ERC20_init(name, symbol);

        validatorId = _validatorId;
        stakingProvider = _stakingProvider;
        logger = _logger;
    }

    /** VIEW METHODS */

    function lockedTokens(address user) public view returns (uint256) {
        uint256 shares = balanceOf(user);
        uint256 rate = exchangeRate();
        if (shares == 0) {
            return 0;
        }

        return (rate * shares) / EXCHANGE_RATE_PRECISION;
    }

    function exchangeRate() public view returns (uint256) {
        uint256 totalShares = totalSupply();
        if (totalShares == 0) {
            return EXCHANGE_RATE_PRECISION;
        }

        return (tokensLocked * EXCHANGE_RATE_PRECISION) / totalShares;
    }

    function withdrawExchangeRate() public view returns (uint256) {
        uint256 _withdrawalSharesPool = withdrawalSharesPool;
        if (_withdrawalSharesPool == 0) {
            return EXCHANGE_RATE_PRECISION;
        }

        return
            (withdrawalTokenPool * EXCHANGE_RATE_PRECISION) /
            _withdrawalSharesPool;
    }

    /** PUBLIC METHODS */

    /// @notice Delegate tokens and mint shares representing a part of the total pool of delegated tokens
    function stake(uint256 amount, uint256 minShares)
        external
        returns (uint256 sharesMinted)
    {}

    function unstake(uint256 claimAmount, uint256 maximumSharesToBurn)
        external
    {
        (uint256 burntShares, uint256 withdrawalShares) = _sellShares(
            claimAmount,
            maximumSharesToBurn
        );

        uint256 unbondNonce = unbondNonces[msg.sender] + 1;

        DelegatorUnbond memory unbond = DelegatorUnbond({
            shares: withdrawalShares,
            withdrawEpoch: stakingProvider.epoch()
        });
        unbonds[msg.sender][unbondNonce] = unbond;
        unbondNonces[msg.sender] = unbondNonce;

        // _getOrCacheEventsHub().logShareBurnedWithId(validatorId, msg.sender, claimAmount, burntShares, unbondNonce);
        // logger.logStakeUpdate(validatorId);
    }

    /// @notice Delegate available token rewards
    function stakeRewards() external returns (uint256 sharesMinted) {}

    /** PRIVATE METHODS */
    function _calculateReward(address user, uint256 _rewardPerShare)
        private
        view
        returns (uint256)
    {
        uint256 shares = balanceOf(user);
        if (shares == 0) {
            return 0;
        }

        uint256 _initialRewardPerShare = initalRewardPerShare[user];
        if (_initialRewardPerShare == _rewardPerShare) {
            return 0;
        }

        return
            ((_rewardPerShare - _initialRewardPerShare) * shares) /
            REWARD_PRECISION;
    }

    function _withdrawReward(address user)
        private
        returns (uint256 liquidRewards)
    {
        // uint256 _rewardPerShare = _calculateRewardPerShareWithRewards(
        //     stakeManager.withdrawDelegatorsReward(validatorId)
        // );
        uint256 _rewardPerShare = 0;
        liquidRewards = _calculateReward(user, _rewardPerShare);

        rewardPerShare = _rewardPerShare;
        initalRewardPerShare[user] = _rewardPerShare;
        return liquidRewards;
    }

    function _withdrawAndTransferReward(address user)
        private
        returns (uint256 withdrawnReward)
    {
        withdrawnReward = _withdrawReward(user);
        if (withdrawnReward != 0) {
            require(
                stakingProvider.transferFunds(
                    validatorId,
                    withdrawnReward,
                    user
                ),
                "Insufficent tokens"
            );
            // logger.logDelegatorClaimRewards(validatorId, user, withdrawnReward);
        }
        return withdrawnReward;
    }

    function _sellShares(uint256 claimAmount, uint256 maximumSharesToBurn)
        private
        returns (uint256 burntShares, uint256 withdrawalShares)
    {
        uint256 totalStaked = lockedTokens(msg.sender);
        require(
            totalStaked != 0 && totalStaked >= claimAmount,
            "Too much requested"
        );

        // convert requested amount back to shares
        burntShares = (claimAmount * EXCHANGE_RATE_PRECISION) / exchangeRate();
        require(burntShares <= maximumSharesToBurn, "too much slippage");

        _withdrawAndTransferReward(msg.sender);
        _burn(msg.sender, burntShares);

        stakingProvider.onDelegatorRemoveStake(validatorId, claimAmount);

        withdrawalShares =
            (claimAmount * EXCHANGE_RATE_PRECISION) /
            withdrawExchangeRate();
        withdrawalTokenPool += claimAmount;
        withdrawalSharesPool += withdrawalShares;

        tokensLocked -= claimAmount;

        return (burntShares, withdrawalShares);
    }

    function _buyShares(uint256 amount, uint256 minShares)
        private
        returns (uint256)
    {
        uint256 rate = exchangeRate();
        uint256 shares = (amount * EXCHANGE_RATE_PRECISION) / rate;
        require(shares >= minShares);

        _mint(_msgSender(), amount);

        // clamp amount of tokens in case resulted shares requires less tokens than anticipated
        amount = (rate * shares) / EXCHANGE_RATE_PRECISION;

        stakingProvider.onDelgatorAddStake(validatorId, amount);

        tokensLocked += amount;

        return amount;
    }

    function _collectRewards() private {}

    /** ERC20 OVERRIDES */

    /// @dev Disable approve to disable any sort of trading
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual override {
        revert("disabled");
    }

    /// @dev Before transfering shares, rewards must be collected for both accounts
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {}
}
