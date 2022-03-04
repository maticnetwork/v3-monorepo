pragma solidity ^0.8.0;

contract SystemCall {
  address public constant SYSTEM_ADDRESS = 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;

  modifier systemCall() {
    _assertSystemCall();
    _;
  }

  function _assertSystemCall() private view {
    require(msg.sender == SYSTEM_ADDRESS, "not system");
  }
}
