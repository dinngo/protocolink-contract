// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {ApproveHelper} from "./libraries/ApproveHelper.sol";

/// @title Router executes arbitrary logics
contract Router is IRouter {
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 public constant BASE = 1e18;

    address public user;

    address public entrant;

    /// @notice Execute logics given expected output tokens and min output amounts
    function execute(address[] calldata tokensOut, uint256[] calldata amountsOutMin, Logic[] calldata logics)
        external
    {
        // Setup user and prevent reentrancy
        if (user != address(0)) revert NotEmptyUser();
        user = msg.sender;

        _execute(tokensOut, amountsOutMin, logics);

        // Reset user
        user = address(0);
    }

    /// @notice Execute when user is set and called from a flash loan callback
    function executeUserSet(address[] calldata tokensOut, uint256[] calldata amountsOutMin, Logic[] calldata logics)
        public
    {
        // Check entrant is set and reset immediately
        if (msg.sender != entrant) revert InvalidEntrant();
        entrant = address(0);

        // Check user is set
        if (user == address(0)) revert EmptyUser();

        _execute(tokensOut, amountsOutMin, logics);
    }

    /// @notice Router executes logics and calls Spenders to consume user's approval, e.g. erc20 and debt tokens
    function _execute(address[] calldata tokensOut, uint256[] calldata amountsOutMin, Logic[] calldata logics)
        private
    {
        // Check parameters
        uint256 tokensOutLength = tokensOut.length;
        if (tokensOutLength != amountsOutMin.length) revert LengthMismatch();

        // Execute each logic
        uint256 logicsLength = logics.length;

        for (uint256 i = 0; i < logicsLength;) {
            address to = logics[i].to;
            bytes memory data = logics[i].data;
            address _entrant = logics[i].entrant;
            AmountInConfig[] memory configs = logics[i].configs;

            // Replace token amount in data with current token balance
            uint256 configsLength = configs.length;
            for (uint256 j = 0; j < configsLength;) {
                address tokenIn = configs[j].tokenIn;
                uint256 ratio = configs[j].tokenInBalanceRatio;
                uint256 offset = configs[j].amountInOffset;
                uint256 amount = IERC20(tokenIn).balanceOf(address(this)) * ratio / BASE;

                assembly {
                    let loc := add(add(data, 0x24), offset) // 0x24 = 0x20(length) + 0x4(sig)
                    mstore(loc, amount)
                }

                // TODO: is max approval safe?
                // Approve max tokenIn
                ApproveHelper._tokenApproveMax(tokenIn, to, amount);

                unchecked {
                    j++;
                }
            }

            // Set entrant who can enter one-time executeUserSet
            if (_entrant != address(0)) entrant = _entrant;

            // Execute
            to.functionCall(data, "ERROR_ROUTER_EXECUTE");

            // Reset entrant if the previous call didn't enter executeUserSet
            if (entrant != address(0)) entrant = address(0);

            unchecked {
                i++;
            }
        }

        // Push tokensOut if any balance and check min amount
        for (uint256 i = 0; i < tokensOutLength;) {
            IERC20 tokenOut = IERC20(tokensOut[i]);
            uint256 amountOutMin = amountsOutMin[i];
            uint256 balance = tokenOut.balanceOf(address(this));

            if (balance < amountOutMin) revert InsufficientBalance(address(tokenOut), amountOutMin, balance);
            if (balance > 0) {
                tokenOut.safeTransfer(user, balance);
            }

            unchecked {
                i++;
            }
        }
    }
}
