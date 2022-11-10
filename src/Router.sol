// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Spender.sol";
import "./interfaces/IRouter.sol";
import "./libraries/ApproveHelper.sol";

import "forge-std/Test.sol";

contract Router is IRouter {
    using SafeERC20 for IERC20;

    Spender public immutable spender;

    constructor() {
        spender = new Spender(address(this));
    }

    /// @notice Router calls Spender to pull user's token
    function execute(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin,
        IRouter.Logic[] calldata logics
    ) external {
        // Read spender into memory to save gas
        Spender _spender = spender;

        // Pull tokenIn
        _spender.transferFromERC20(msg.sender, tokenIn, amountIn);

        for (uint256 i = 0; i < logics.length; i++) {
            // Assignments
            address to = logics[i].to;
            address token = logics[i].token;
            uint256 amountOffset = logics[i].amountOffset;
            bytes memory data = logics[i].data;

            // Replace amount with current balance
            uint256 amount = IERC20(token).balanceOf(address(this));
            assembly {
                let loc := add(add(data, 0x24), amountOffset) // 0x24 = 0x20(length) + 0x4(sig)
                mstore(loc, amount)
            }

            // Approve tokenIn
            ApproveHelper._tokenApprove(token, to, type(uint256).max);

            // Execute
            require(to != address(_spender), "SPENDER");
            (bool success,) = to.call(data);
            require(success, "FAIL");

            // Approve zero
            ApproveHelper._tokenApproveZero(token, to);
        }

        // Read amounts
        uint256 amountInAfter = IERC20(tokenIn).balanceOf(address(this));
        uint256 amountOutAfter = IERC20(tokenOut).balanceOf(address(this));

        // Check minimal amount
        require(amountOutAfter >= amountOutMin, "AMOUNT_OUT");

        // Push tokenIn and tokenOut if any balance
        if (amountInAfter > 0) {
            IERC20(tokenIn).safeTransfer(msg.sender, amountInAfter);
        }
        if (amountOutAfter > 0) {
            IERC20(tokenOut).safeTransfer(msg.sender, amountOutAfter);
        }
    }
}
