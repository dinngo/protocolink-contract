// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/ISpender.sol";

/// @notice Users can approve maximal amount to this
contract Spender is ISpender {
    using SafeERC20 for IERC20;

    address public immutable router;

    constructor(address router_) {
        router = router_;
    }

    /// @notice Router asks to transfer tokens from user
    /// @dev Router must guarantee that only consumes the approval from a correct user.
    function pull(address token, uint256 amount) external {
        address _router = router;
        address user = IRouter(_router).msgSender();
        require(user != address(0), "INVALID_USER");

        IERC20(token).safeTransferFrom(user, _router, amount);
    }
}
