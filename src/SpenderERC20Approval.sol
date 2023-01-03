// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/ISpenderERC20Approval.sol";

/// @notice Users can approve max amount here
contract SpenderERC20Approval is ISpenderERC20Approval {
    using SafeERC20 for IERC20;

    address public immutable router;

    constructor(address router_) {
        router = router_;
    }

    /// @notice Router asks to transfer tokens from the user
    /// @dev Router must guarantee that the public user is msg.sender who called Router.
    function pull(address token, uint256 amount) external {
        address _router = router;
        address user = IRouter(_router).user();
        require(user != address(0), "INVALID_USER");

        IERC20(token).safeTransferFrom(user, _router, amount);
    }
}
