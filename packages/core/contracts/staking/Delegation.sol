pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/IDelegationLogger.sol";
import "./interfaces/IDelegationReactor.sol";

contract Delegation is ERC20Upgradeable {
    struct DelegatorUnbond {
        uint256 shares;
        uint256 withdrawEpoch;
    }

    uint256 constant EXCHANGE_RATE_PRECISION = 10**29;
    uint256 constant REWARD_PRECISION = 10**25;

    IDelegationLogger public logger;
    IDelegationReactor public delegationReactor;

    uint256 public validatorId;
    uint256 public tokensLocked;

    mapping(address => uint256) public initalRewardPerShare;
    mapping(address => DelegatorUnbond) public unbonds;

    // track how many tokens per share to distribute
    uint256 public rewardPerShare;
    uint256 public withdrawPool;
    uint256 public withdrawShares;

    function initialize(
        uint256 _validatorId,
        IDelegationReactor _delegationReactor,
        IDelegationLogger _logger
    ) external initializer {
        // give shares meaningful name
        string memory name = string(
            abi.encodePacked("Delegation Shares ", _validatorId)
        );
        string memory symbol = string(abi.encodePacked("DS", _validatorId));
        __ERC20_init(name, symbol);

        validatorId = _validatorId;
        delegationReactor = _delegationReactor;
        logger = _logger;
    }

    /** PUBLIC VIEW METHODS */

    function lockedTokens(address user)
        public
        view
        returns (uint256)
    {
        uint256 shares = balanceOf(user);
        uint256 rate = exchangeRate();
        if (shares == 0) {
            return 0;
        }

        return rate * shares / EXCHANGE_RATE_PRECISION;
    }

    function exchangeRate() public view returns (uint256) {
        uint256 totalShares = totalSupply();
        if (totalShares == 0) {
            return EXCHANGE_RATE_PRECISION;
        }

        return tokensLocked * EXCHANGE_RATE_PRECISION / totalShares;
    }

    function withdrawExchangeRate() public view returns (uint256) {
        uint256 _withdrawShares = withdrawShares;
        if (_withdrawShares == 0) {
            return EXCHANGE_RATE_PRECISION;
        }

        return (withdrawPool * EXCHANGE_RATE_PRECISION) / _withdrawShares;
    }

    /** PUBLIC METHODS */

    function addTokens(uint256 amount, uint256 minShares) external {}

    function removeTokens(uint256 claimAmount, uint256 maximumSharesToBurn)
        external
    {
        (uint256 shares, uint256 _withdrawPoolShare) = _sellShares(
            claimAmount,
            maximumSharesToBurn
        );

        DelegatorUnbond memory unbond = unbonds[msg.sender];
        unbond.shares += _withdrawPoolShare;
        // refresh undond period
        // unbond.withdrawEpoch = stakeManager.epoch();
        unbonds[msg.sender] = unbond;
    }

    function delegateRewards() external {}

    /** PRIVATE METHODS */

    function _sellShares(uint256 claimAmount, uint256 maximumSharesToBurn)
        private
        returns (uint256, uint256)
    {
        uint256 totalStaked = lockedTokens(msg.sender);
        require(
            totalStaked != 0 && totalStaked >= claimAmount,
            "Too much requested"
        );

        uint256 rate = exchangeRate();

        // convert requested amount back to shares
        uint256 shares = (claimAmount * EXCHANGE_RATE_PRECISION) / rate;
        require(shares <= maximumSharesToBurn, "too much slippage");

        // _withdrawAndTransferReward(msg.sender);

        _burn(msg.sender, shares);
        delegationReactor.onDelegatorRemoveStake(validatorId, claimAmount);

        tokensLocked -= claimAmount;

        uint256 _withdrawPoolShare = (claimAmount * EXCHANGE_RATE_PRECISION) /
            withdrawExchangeRate();
        // withdrawPool = withdrawPool.add(claimAmount);
        // withdrawShares = withdrawShares.add(_withdrawPoolShare);

        return (shares, _withdrawPoolShare);
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

        delegationReactor.onDelgatorAddStake(validatorId, amount);

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
