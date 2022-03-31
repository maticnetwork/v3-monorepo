pragma solidity ^0.8.0;

import "../proxies/DelegationProxy.sol";
import "./Delegation.sol";

contract DelegationProxyCreator {
    address public beacon;

    constructor(address _beacon) {
        beacon = _beacon;
    }

    function create(uint256 validatorId, address _logger)
        external
        returns (address)
    {
        DelegationProxy proxy = new DelegationProxy(
            beacon,
            abi.encodeWithSelector(
                Delegation(address(0)).initialize.selector,
                validatorId,
                msg.sender,
                _logger
            ),
            msg.sender
        );
        return address(proxy);
    }
}
