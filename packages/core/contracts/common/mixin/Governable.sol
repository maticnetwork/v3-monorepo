pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./../governance/IGovernance.sol";

contract Governable is Initializable {
    address public governance;

    modifier onlyGovernance() {
        _assertGovernance();
        _;
    }

    function _assertGovernance() private view {
        require(
            msg.sender == governance,
            "not governance"
        );
    }

    function _init_governable(address _governance) internal onlyInitializing {
        governance = _governance;
    }
}
