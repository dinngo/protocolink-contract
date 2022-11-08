// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC20Usdt {
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external;
}

/// @title ApproveHelper
/// @notice Contains helper methods for interacting with ERC20 tokens that have inconsistent implementation
library ApproveHelper {
    using SafeERC20 for IERC20;

    function _tokenApprove(address token, address spender, uint256 amount) internal {
        try IERC20Usdt(token).approve(spender, amount) {}
        catch {
            IERC20(token).safeApprove(spender, 0);
            IERC20(token).safeApprove(spender, amount);
        }
    }

    function _tokenApproveZero(address token, address spender) internal {
        if (IERC20Usdt(token).allowance(address(this), spender) > 0) {
            try IERC20Usdt(token).approve(spender, 0) {}
            catch {
                IERC20Usdt(token).approve(spender, 1);
            }
        }
    }
}
