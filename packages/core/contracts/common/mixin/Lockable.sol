pragma solidity ^0.8.0;

contract Lockable {
    bool public locked;

    modifier onlyWhenUnlocked() {
        _assertUnlocked();
        _;
    }

    function _assertUnlocked() private view {
        require(!locked, "locked");
    }

    function _lock() internal {
        locked = true;
    }

    function _unlock() internal {
        locked = false;
    }
}
