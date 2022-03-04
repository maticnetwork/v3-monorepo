pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract ContractRegistry is OwnableUpgradeable {
    mapping(bytes32 => address) public contracts;

    event ContractAddressUpdated(
        string contractname,
        bytes32 indexed hash,
        address contractAddress
    );

    function initialize() external initializer {
        __Ownable_init();
    }

    function setContractAddress(string memory contractName, address addr)
        external
        onlyOwner
    {
        bytes32 hash = _toHash(contractName);
        contracts[hash] = addr;

        emit ContractAddressUpdated(contractName, hash, addr);
    }

    function getContractAddressByName(string memory contractName)
        external
        view
        returns (address)
    {
        return contracts[_toHash(contractName)];
    }

    function _toHash(string memory str) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(str));
    }
}
