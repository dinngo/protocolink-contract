// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {ApproveHelper} from "./libraries/ApproveHelper.sol";

/// @title Router executes arbitrary logics
contract Router is IRouter {
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 public constant BPS_BASE = 10_000;

    address public user;

    address private _entrant;

    /// @notice Execute logics given expected output tokens and min output amounts
    function execute(address[] calldata tokensReturn, Logic[] calldata logics) external {
        // Setup user and prevent reentrancy
        if (user != address(0)) revert NotEmptyUser();
        user = msg.sender;

        _execute(tokensReturn, logics);

        // Reset user
        user = address(0);
    }

    /// @notice Execute when user is set and called from a flash loan callback
    function executeByEntrant(address[] calldata tokensReturn, Logic[] calldata logics) external {
        // Check _entrant is set and reset immediately
        if (msg.sender != _entrant) revert InvalidEntrant();
        _entrant = address(0);

        // Check user is set
        if (user == address(0)) revert EmptyUser();

        _execute(tokensReturn, logics);
    }

    /// @notice Router executes logics and calls Spenders to consume user's approval, e.g. erc20 and debt tokens
    function _execute(address[] calldata tokensReturn, Logic[] calldata logics) private {
        // Check parameters
        uint256 tokensReturnLength = tokensReturn.length;

        // Execute each logic
        uint256 logicsLength = logics.length;
        for (uint256 i = 0; i < logicsLength;) {
            address to = logics[i].to;
            bytes memory data = logics[i].data;
            Input[] memory inputs = logics[i].inputs;
            Output[] memory outputs = logics[i].outputs;
            address entrant = logics[i].entrant;

            // Execute each input
            uint256 inputsLength = inputs.length;
            for (uint256 j = 0; j < inputsLength;) {
                address token = inputs[j].token;
                uint256 amountOffset = inputs[j].amountOffset;
                uint256 amount = IERC20(token).balanceOf(address(this)) * inputs[j].amountBps / BPS_BASE;

                // Replace the amount in data with the calculated token amount by bps
                assembly {
                    let loc := add(add(data, 0x24), amountOffset) // 0x24 = 0x20(length) + 0x4(sig)
                    mstore(loc, amount)
                }

                // Approve max token
                if (inputs[j].doApprove) ApproveHelper._approve(token, to, amount);

                unchecked {
                    j++;
                }
            }

            // Set _entrant who can enter one-time executeByEntrant
            if (entrant != address(0)) _entrant = entrant;

            // Execute
            to.functionCall(data, "ERROR_ROUTER_EXECUTE");

            // Reset _entrant if the previous call didn't enter executeByEntrant
            if (_entrant != address(0)) _entrant = address(0);

            // Reset to zero approval
            for (uint256 j = 0; j < inputsLength;) {
                if (inputs[j].doApprove) ApproveHelper._approveZero(inputs[j].token, to);

                unchecked {
                    j++;
                }
            }

            // Execute each output
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
