// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAgent} from './interfaces/IAgent.sol';
import {IParam} from './interfaces/IParam.sol';
import {IRouter} from './interfaces/IRouter.sol';

/// @title Implemtation contract of agent logics
contract AgentImplementation is IAgent {
    using SafeERC20 for IERC20;
    using Address for address;
    using Address for address payable;

    address private constant _NATIVE = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    uint256 private constant _BPS_BASE = 10_000;
    uint256 private constant _SKIP = type(uint256).max;

    address public immutable router;

    address private _caller;


    modifier checkCaller() {
        address caller = _caller;
        if (caller != msg.sender) {
            // Only predefined caller can call agent
            revert InvalidCaller();
        } else if (caller != router) {
            // When the caller is not router, should be reset right away to guarantee one-time usage from callback contracts
            _caller = router;
        }
        _;
    }

    constructor() {
        router = msg.sender;
    }

    function initialize() external {
        if (_caller != address(0)) revert Initialized();
        _caller = router;
    }

    /// @notice Execute logics and return tokens to user
    function execute(IParam.Logic[] calldata logics, address[] calldata tokensReturn) external payable checkCaller {
        // TODO: chained ret value for PoC only
        uint256 size = 1024;
        bytes[] memory retValues = new bytes[](size);

        // Execute each logic
        uint256 logicsLength = logics.length;
        for (uint256 i = 0; i < logicsLength; ) {
            address to = logics[i].to;
            bytes memory data = logics[i].data;
            IParam.Input[] calldata inputs = logics[i].inputs;
            address callback = logics[i].callback;
            uint256 value = logics[i].value;

            // Get ret values (would skip if length = 0)
            // TODO: stack too deep
            // uint256 inputsLength = inputs.length;
            for (uint256 j = 0; j < inputs.length/*inputsLength*/; ) {
                if(retValues.length == 0) break; // no saved ret value

                uint256 offsetLength = inputs[j].retOffsets.length;
                require(offsetLength > 0, 'no offset');
                require(offsetLength == inputs[j].dataOffsets.length, "data length mismatch");
                require(offsetLength == inputs[j].amountBps.length, "bps length mismatch");

                uint256 index = inputs[j].index;
                bytes memory retdata = retValues[index];
                {
                    // get native token amount for msg.value
                    uint256 valueOffset = inputs[j].valueOffset;
                    uint256 valueBps = inputs[j].valueBps;
                    if (valueOffset != _SKIP) {
                        assembly {
                            // TODO: should we add length of bytes here too?
                            let valueLoc := add(retdata, valueOffset)
                            value := div(mul(mload(valueLoc), valueBps), _BPS_BASE)
                        }
                    }
                }


                // replace data with ret values
                for (uint256 k = 0; k < inputs[j].retOffsets.length;) {
                    uint256 amountBps = inputs[j].amountBps[k];
                    if (amountBps > _BPS_BASE) revert InvalidBps();
                    {
                        uint256 retOffset = inputs[j].retOffsets[k];
                        uint256 dataOffset = inputs[j].dataOffsets[k];

                        assembly {
                            let retLoc := add(retdata, retOffset)
                            let retVal := div(mul(mload(retLoc), amountBps), _BPS_BASE)
                            let dataLoc := add(add(data, 0x24), dataOffset) // 0x24 = 0x20(data_length) + 0x4(sig)
                            mstore(dataLoc,retVal)
                        }
                    }
                    unchecked {
                        ++k;
                    }
                }

                unchecked {
                    ++j;
                }
            }

            // Set _callback who should enter one-time execute
            if (callback != address(0)) _caller = callback;

            // Execute and send native
            if (data.length == 0) {
                payable(to).sendValue(value);
            } else {
                bytes memory retData = to.functionCallWithValue(data, value, 'ERROR_ROUTER_EXECUTE');
                if (logics[i].chained) {
                    retValues[i] = retData;
                }
            }

            // Revert if the previous call didn't enter execute
            if (_caller != router) revert UnresetCallback();

            unchecked {
                ++i;
            }
        }

        // Push tokensReturn if any balance
        uint256 tokensReturnLength = tokensReturn.length;
        if (tokensReturnLength > 0) {
            address user = IRouter(router).user();
            for (uint256 i = 0; i < tokensReturnLength; ) {
                address token = tokensReturn[i];
                if (token == _NATIVE) {
                    payable(user).sendValue(address(this).balance);
                } else {
                    uint256 balance = IERC20(token).balanceOf(address(this));
                    IERC20(token).safeTransfer(user, balance);
                }

                unchecked {
                    ++i;
                }
            }
        }
    }

    function _getBalance(address token) private view returns (uint256 balance) {
        if (token == _NATIVE) {
            balance = address(this).balance;
        } else {
            balance = IERC20(token).balanceOf(address(this));
        }
    }
}
