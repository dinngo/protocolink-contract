// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/Address.sol";

/// @notice Users can approve maximal amount to spender
contract Spender {
    using SafeERC20 for IERC20;

    address public immutable router;

    constructor(address router_) {
        router = router_;
    }

    /// @notice Router asks to transfer tokens from user to router
    /// @dev Router must guarantee that from is the user (msg.sender)
    function transferFromERC20(address from, address token, uint256 amount) external {
        require(msg.sender == router, "!ROUTER");

        IERC20(token).safeTransferFrom(from, router, amount);
    }
}
