pragma solidity ^0.8.0;

import "./IGovernance.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Governance is OwnableUpgradeable, IGovernance {
    function initialize() external initializer {
        __Ownable_init();
    }

    function update(address target, bytes calldata data)
        external
        override
        onlyOwner
    {
        (bool success, ) = target.call(data); /* bytes memory returnData */
        require(success, "Update failed");
    }
}
