pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract DelegationBeacon is UpgradeableBeacon {
    constructor(address implementation) UpgradeableBeacon(implementation) {}
}
