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
    uint256 private constant _SKIP = type(uint256).max;

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
            address approveTo = logics[i].approveTo;
            address callback = logics[i].callback;

            // Revert approve sig to prevent Router from approving arbitrary address
            // Revert transferFrom sig to prevent user from mistakenly approving Router and being exploited
            bytes4 sig = bytes4(data);
            if (sig == IERC20.approve.selector || sig == IERC20.transferFrom.selector) {
                revert InvalidERC20Sig();
            }

            // Default `approveTo` is same as `to` unless `approveTo` is set
            if (approveTo == address(0)) {
                approveTo = to;
            }

            // Execute each input if need to modify the amount or do approve
            uint256 value;
            uint256 inputsLength = inputs.length;
            for (uint256 j = 0; j < inputsLength; ) {
                address token = inputs[j].token;
                uint256 amountBps = inputs[j].amountBps;

                // Calculate native or token amount
                // 1. if amountBps is skip: read amountOrOffset as amount
                // 2. if amountBps isn't skip: balance multiplied by amountBps as amount
                // 3. if amountBps isn't skip and amountOrOffset isn't skip:
                //    => replace the amount at offset equal to amountOrOffset with the calculated amount
                uint256 amount;
                if (amountBps == _SKIP) {
                    amount = inputs[j].amountOrOffset;
                } else {
                    if (amountBps == 0 || amountBps > _BPS_BASE) revert InvalidBps();
                    amount = (_getBalance(token) * amountBps) / _BPS_BASE;

                    // Skip if don't need to replace, e.g., most protocols set native amount in call value
                    uint256 offset = inputs[j].amountOrOffset;
                    if (offset != _SKIP) {
                        assembly {
                            let loc := add(add(data, 0x24), offset) // 0x24 = 0x20(data_length) + 0x4(sig)
                            mstore(loc, amount)
                        }
                    }
                }

                // Set native token value or approve ERC20 if `to` isn't the token self
                if (token == _NATIVE) {
                    value = amount;
                } else if (token != approveTo) {
                    ApproveHelper._approve(token, approveTo, amount);
                }

                unchecked {
                    j++;
                }
            }

            // Store initial output token balances
            uint256 outputsLength = outputs.length;
            uint256[] memory outputInitBalances = new uint256[](outputsLength);
            for (uint256 j = 0; j < outputsLength; ) {
                outputInitBalances[j] = _getBalance(outputs[j].token);

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
                address token = inputs[j].token;
                if (token != _NATIVE && token != approveTo) {
                    ApproveHelper._approveZero(token, approveTo);
                }

                unchecked {
                    j++;
                }
            }

            // Execute each output to hard check the min amounts are expected
            for (uint256 j = 0; j < outputsLength; ) {
                address token = outputs[j].token;
                uint256 amountMin = outputs[j].amountMin;
                uint256 balance = _getBalance(token) - outputInitBalances[j];

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
