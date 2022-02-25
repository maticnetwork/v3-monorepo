pragma solidity ^0.8.0;

import  "./IGovernance.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Governance is Ownable, IGovernance {
    function update(address target, bytes calldata data) external override onlyOwner {
        (bool success, ) = target.call(data); /* bytes memory returnData */
        require(success, "Update failed");
    }
}
