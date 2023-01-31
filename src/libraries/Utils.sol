// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

///@notice Include some common functions.
library Utils {
    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function _getBalance(address token, uint256 amount) internal view returns (uint256) {
        if (amount != type(uint256).max) {
            return amount;
        }

        // ETH case
        if (token == NATIVE_TOKEN_ADDRESS) {
            return address(this).balance;
        } else {
            // ERC20 token case
            return IERC20(token).balanceOf(address(this));
        }
    }
}
