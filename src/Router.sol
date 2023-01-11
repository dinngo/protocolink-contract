// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {ApproveHelper} from "./libraries/ApproveHelper.sol";

/// @title Router executes arbitrary logics
contract Router is IRouter {
    using SafeERC20 for IERC20;
    using Address for address;

    address private constant _INIT_USER = address(1);
    address private constant _INIT_CALLBACK = address(2);
    uint256 private constant _BPS_BASE = 10_000;

    address public user;
    address private _callback;

    constructor() {
        user = _INIT_USER;
        _callback = _INIT_CALLBACK;
    }

    /// @notice Execute logics and return tokens to user
    function execute(Logic[] calldata logics, address[] calldata tokensReturn) external {
        // Setup user and prevent reentrancy
        if (user != _INIT_USER) revert InvalidUser();
        user = msg.sender;

        _execute(logics, tokensReturn);

        // Reset user
        user = _INIT_USER;
    }

    /// @notice Execute when user is set and called from a flash loan callback
    /// @dev As only execute -> _execute can enter this function, user must be valid here
    function executeByCallback(Logic[] calldata logics, address[] calldata tokensReturn) external {
        // Check _callback is set and reset _callback immediately
        if (msg.sender != _callback) revert InvalidCallback();
        _callback = _INIT_CALLBACK;

        _execute(logics, tokensReturn);
    }

    /// @notice Router executes logics and calls Spenders to consume user's approval, e.g. erc20 and debt tokens
    function _execute(Logic[] calldata logics, address[] calldata tokensReturn) private {
        // Execute each logic
        uint256 logicsLength = logics.length;
        for (uint256 i = 0; i < logicsLength;) {
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
            uint256 inputsLength = inputs.length;
            for (uint256 j = 0; j < inputsLength;) {
                address token = inputs[j].token;
                uint256 amountOffset = inputs[j].amountOffset;
                uint256 amountBps = inputs[j].amountBps;

                if (amountBps == 0 || amountBps > _BPS_BASE) revert InvalidBps();

                // Replace the amount in data with the calculated token amount by bps
                uint256 amount = IERC20(token).balanceOf(address(this)) * amountBps / _BPS_BASE;
                assembly {
                    let loc := add(add(data, 0x24), amountOffset) // 0x24 = 0x20(length) + 0x4(sig)
                    mstore(loc, amount)
                }

                // Approve token
                if (inputs[j].doApprove) ApproveHelper._approve(token, to, amount);

                unchecked {
                    j++;
                }
            }

            // Set _callback who should enter one-time executeByCallback
            if (callback != address(0)) _callback = callback;

            // Execute
            to.functionCall(data, "ERROR_ROUTER_EXECUTE");

            // Revert if the previous call didn't enter executeByCallback
            if (_callback != _INIT_CALLBACK) revert UnresetCallback();

            // Reset approval
            for (uint256 j = 0; j < inputsLength;) {
                if (inputs[j].doApprove) ApproveHelper._approveZero(inputs[j].token, to);

                unchecked {
                    j++;
                }
            }

            // Execute each output to hard check the min amounts are expected
            uint256 outputsLength = outputs.length;
            for (uint256 j = 0; j < outputsLength;) {
                IERC20 token = IERC20(outputs[j].token);
                uint256 amountMin = outputs[j].amountMin;
                uint256 balance = token.balanceOf(address(this));

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
        for (uint256 i = 0; i < tokensReturnLength;) {
            IERC20 tokenReturn = IERC20(tokensReturn[i]);
            uint256 balance = tokenReturn.balanceOf(address(this));

            if (balance > 0) {
                tokenReturn.safeTransfer(user, balance);
            }

            unchecked {
                i++;
            }
        }
    }
}
