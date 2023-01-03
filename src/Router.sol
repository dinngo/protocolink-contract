// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IRouter.sol";
import "./libraries/ApproveHelper.sol";

contract Router is IRouter, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 public constant BASE = 1e18;

    address public user;

    /// @notice Execute logics given expected output tokens and min output amounts
    function execute(address[] calldata tokensOut, uint256[] calldata amountsOutMin, Logic[] calldata logics)
        external
    {
        // Setup user and prevent reentrancy
        require(user == address(0), "SHOULD_EMPTY_USER");
        user = msg.sender;

        _execute(tokensOut, amountsOutMin, logics);

        // Reset user
        user = address(0);
    }

    /// @notice Execute when user is set called by flashloan callback
    function executeUserSet(address[] calldata tokensOut, uint256[] calldata amountsOutMin, Logic[] calldata logics)
        public
        nonReentrant
    {
        // Check user is set.
        require(user != address(0), "EMPTY_USER");

        _execute(tokensOut, amountsOutMin, logics);
    }

    /// @notice Router executes logics and calls Spenders to consume user's approval, e.g. erc20 and debt tokens
    function _execute(address[] calldata tokensOut, uint256[] calldata amountsOutMin, Logic[] calldata logics)
        private
    {
        // Check parameters
        require(tokensOut.length == amountsOutMin.length, "UNEQUAL_LENGTH");

        // Execute each logic
        for (uint256 i = 0; i < logics.length; i++) {
            address to = logics[i].to;
            AmountInConfig[] memory configs = logics[i].configs;
            bytes memory data = logics[i].data;

            // Replace token amount in data with current token balance
            for (uint256 j = 0; j < configs.length; j++) {
                address tokenIn = configs[j].tokenIn;
                uint256 ratio = configs[j].tokenInBalanceRatio;
                uint256 offset = configs[j].amountInOffset;
                uint256 amount = IERC20(tokenIn).balanceOf(address(this)) * ratio / BASE;

                assembly {
                    let loc := add(add(data, 0x24), offset) // 0x24 = 0x20(length) + 0x4(sig)
                    mstore(loc, amount)
                }

                // Approve max tokenIn
                ApproveHelper._tokenApproveMax(tokenIn, to, amount);
            }

            // Execute
            to.functionCall(data, "ERROR_ROUTER_EXECUTE");
        }

        // Push tokensOut if any balance and check minimal amount
        for (uint256 i = 0; i < tokensOut.length; i++) {
            uint256 balance = IERC20(tokensOut[i]).balanceOf(address(this));
            require(balance >= amountsOutMin[i], "INSUFFICIENT_AMOUNT_OUT");

            if (balance > 0) {
                IERC20(tokensOut[i]).safeTransfer(user, balance);
            }
        }
    }
}
