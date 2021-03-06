pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract DelegationProxy is BeaconProxy {
    constructor(
        address beacon,
        bytes memory data,
        address admin
    ) payable BeaconProxy(beacon, data) {
        _changeAdmin(admin);
    }
}
