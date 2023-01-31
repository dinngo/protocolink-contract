// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {ApproveHelper} from './libraries/ApproveHelper.sol';

/// @title Router executes arbitrary logics
contract Router is IRouter {
    using SafeERC20 for IERC20;
    using Address for address;
    using Address for address payable;

    address private constant _INIT_USER = address(1);
    address private constant _INIT_CALLBACK = address(2);
    address private constant _NATIVE = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    uint256 private constant _BPS_BASE = 10_000;

    address public user;
    address private _callback;

    constructor() {
        user = _INIT_USER;
        _callback = _INIT_CALLBACK;
    }

    receive() external payable {}

    /// @notice Execute logics and return tokens to user
    function execute(Logic[] calldata logics, address[] calldata tokensReturn) external payable {
        // Setup user and prevent reentrancy
        bool fUserSet;
        if (user == _INIT_USER) {
            user = msg.sender;
            fUserSet = true;
        } else {
            // If the user is set, execute should be called through callback
            if (_callback != msg.sender) {
                revert InvalidCallback();
            } else {
                _callback = _INIT_CALLBACK;
            }
        }

        _execute(logics, tokensReturn);

        // Reset user
        if (fUserSet) {
            user = _INIT_USER;
        }
    }

    /// @notice Router executes logics and calls Spenders to consume user's approval, e.g. erc20 and debt tokens
    function _execute(Logic[] calldata logics, address[] calldata tokensReturn) private {
        // Execute each logic
        uint256 logicsLength = logics.length;
        for (uint256 i = 0; i < logicsLength; ) {
            address to = logics[i].to;
            bytes memory data = logics[i].data;
            Input[] memory inputs = logics[i].inputs;
            Output[] memory outputs = logics[i].outputs;
            address callback = logics[i].callback;

            // Revert approve sig for soft avoiding giving approval from Router
            // Revert transferFrom sig for avoiding exploiting user's approval to Router by mistake
            bytes4 sig = bytes4(data);
            if (sig == IERC20.approve.selector || sig == IERC20.transferFrom.selector) {
                revert InvalidERC20Sig();
            }

            // Execute each input
            uint256 value;
            uint256 inputsLength = inputs.length;
            for (uint256 j = 0; j < inputsLength; ) {
                address token = inputs[j].token;
                uint256 amountOffset = inputs[j].amountOffset;
                uint256 amountBps = inputs[j].amountBps;

                if (amountBps == 0 || amountBps > _BPS_BASE) revert InvalidBps();

                // Calculate amount by bps
                uint256 balance = _getBalance(token);
                uint256 amount = (balance * amountBps) / _BPS_BASE;

                // Replace amount in data if offset is valid
                if (amountOffset != type(uint256).max) {
                    assembly {
                        let loc := add(add(data, 0x24), amountOffset) // 0x24 = 0x20(length) + 0x4(sig)
                        mstore(loc, amount)
                    }
                }

                // Approve ERC20 or set native token value
                if (inputs[j].doApprove) ApproveHelper._approve(token, to, amount);
                else if (token == _NATIVE) value = amount;

                unchecked {
                    j++;
                }
            }

            // Store initial output token amount
            uint256 outputsLength = outputs.length;
            uint256[] memory outputInitBalance = new uint256[](outputsLength);
            for (uint256 j = 0; j < outputsLength; ) {
                address token = outputs[j].token;
                outputInitBalance[j] = _getBalance(token);

                unchecked {
                    j++;
                }
            }

            // Set _callback who should enter one-time execute
            if (callback != address(0)) _callback = callback;

            // Execute
            to.functionCallWithValue(data, value, 'ERROR_ROUTER_EXECUTE');

            // Revert if the previous call didn't enter execute
            if (_callback != _INIT_CALLBACK) revert UnresetCallback();

            // Reset approval
            for (uint256 j = 0; j < inputsLength; ) {
                if (inputs[j].doApprove) ApproveHelper._approveZero(inputs[j].token, to);

                unchecked {
                    j++;
                }
            }

            // Execute each output to hard check the min amounts are expected
            for (uint256 j = 0; j < outputsLength; ) {
                address token = outputs[j].token;
                uint256 amountMin = outputs[j].amountMin;
                uint256 balance = _getBalance(token) - outputInitBalance[j];

                // Check min amount
                if (balance < amountMin) revert InsufficientBalance(address(token), amountMin, balance);

                unchecked {
                    j++;
                }
            }

            unchecked {
                i++;
            }
        }

        // Push tokensReturn if any balance
        uint256 tokensReturnLength = tokensReturn.length;
        for (uint256 i = 0; i < tokensReturnLength; ) {
            address token = tokensReturn[i];
            uint256 balance = _getBalance(token);
            if (token == _NATIVE) {
                payable(user).sendValue(balance);
            } else {
                IERC20(token).safeTransfer(user, balance);
            }

            unchecked {
                i++;
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
