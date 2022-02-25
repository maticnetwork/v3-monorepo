pragma solidity ^0.8.0;

import "../../common/lib/rlp/RLPReader.sol";
import "../../common/mixin/SystemCall.sol";
import "./interfaces/IStateReceiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract StateReceiver is SystemCall {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    uint256 public lastStateId;

    function commitState(bytes calldata recordBytes)
        external
        systemCall
        returns (bool success)
    {
        // parse state data
        RLPReader.RLPItem[] memory dataList = recordBytes.toRlpItem().toList();
        uint256 stateId = dataList[0].toUint();
        require(lastStateId + 1 == stateId, "StateIds are not sequential");
        lastStateId++;

        address receiver = dataList[1].toAddress();
        bytes memory stateData = dataList[2].toBytes();
        // notify state receiver contract, in a non-revert manner
        if (Address.isContract(receiver)) {
            uint256 txGas = 5000000;
            bytes memory data = abi.encodeWithSelector(
                IStateReceiver(address(0)).onStateReceive.selector,
                stateId,
                stateData
            );

            (success, ) = receiver.call{value: 0, gas: txGas}(data);
        }
    }
}
