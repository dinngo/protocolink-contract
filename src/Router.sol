// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Spender.sol";
import "./interfaces/IRouter.sol";
import "./libraries/ApproveHelper.sol";

contract Router is IRouter {
    using SafeERC20 for IERC20;

    Spender public immutable spender;

    constructor() {
        spender = new Spender(address(this));
    }

    /// @notice Router calls Spender to pull user's token
    function execute(address tokenIn, uint256 amountIn, address tokenOut, address to, bytes calldata data) external {
        require(to != address(spender), "SPENDER");

        // Pull tokenIn
        spender.transferFromERC20(msg.sender, tokenIn, amountIn);

        // Approve tokenIn
        ApproveHelper._tokenApprove(tokenIn, to, type(uint256).max);

        // Execute
        (bool success,) = to.call(data);
        require(success, "FAIL");

        // Approve zero
        ApproveHelper._tokenApproveZero(tokenIn, to);

        // Push tokenIn and tokenOut
        if (IERC20(tokenIn).balanceOf(address(this)) > 0) {
            IERC20(tokenIn).safeTransfer(msg.sender, IERC20(tokenIn).balanceOf(address(this)));
        }
        if (IERC20(tokenOut).balanceOf(address(this)) > 0) {
            IERC20(tokenOut).safeTransfer(msg.sender, IERC20(tokenOut).balanceOf(address(this)));
        }
    }
}
