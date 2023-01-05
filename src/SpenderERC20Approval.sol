// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {ISpenderERC20Approval} from "./interfaces/ISpenderERC20Approval.sol";

/// @title Spender for ERC20 token approval where users can approve max amount
contract SpenderERC20Approval is ISpenderERC20Approval {
    using SafeERC20 for IERC20;

    address public immutable router;

    constructor(address router_) {
        router = router_;
    }

    /// @notice Router asks to transfer tokens from the user
    /// @dev Router must guarantee that the public user is msg.sender who called Router.
    function pullToken(address token, uint256 amount) external {
        address user = IRouter(router).user();
        if (user == address(0)) revert RouterEmptyUser();

        _pull(token, amount, user);
    }

    function pullTokens(address[] calldata tokens, uint256[] calldata amounts) external {
        address user = IRouter(router).user();
        if (user == address(0)) revert RouterEmptyUser();

        uint256 tokensLength = tokens.length;
        if (tokensLength != amounts.length) revert LengthMismatch();

        for (uint256 i = 0; i < tokensLength;) {
            _pull(tokens[i], amounts[i], user);

            unchecked {
                i++;
            }
        }
    }

    function _pull(address token, uint256 amount, address user) private {
        IERC20(token).safeTransferFrom(user, router, amount);
    }
}
