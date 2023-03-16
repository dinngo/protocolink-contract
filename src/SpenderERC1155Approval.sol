// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC1155} from 'openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {ISpenderERC1155Approval} from './interfaces/ISpenderERC1155Approval.sol';

/// @title Spender for ERC1155 token approval where users can approve the collection
contract SpenderERC1155Approval is ISpenderERC1155Approval {
    address public immutable router;

    constructor(address router_) {
        router = router_;
    }

    /// @notice Router asks to transfer tokens from the user
    /// @dev Router must guarantee that the public user is msg.sender who called Router.
    function pullToken(
        address token,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external {
        (address user, address agent) = IRouter(router).getUserAgent();
        if (msg.sender != agent) revert InvalidAgent();

        _pull(token, tokenIds, amounts, user);
    }

    function pullTokens(
        address[] calldata tokens,
        uint256[][] calldata tokenIdsArray,
        uint256[][] calldata amountsArray
    ) external {
        (address user, address agent) = IRouter(router).getUserAgent();
        if (msg.sender != agent) revert InvalidAgent();

        uint256 tokensLength = tokens.length;
        if (tokensLength != tokenIdsArray.length) revert LengthMismatch();
        for (uint256 i = 0; i < tokensLength; ) {
            _pull(tokens[i], tokenIdsArray[i], amountsArray[i], user);
            unchecked {
                ++i;
            }
        }
    }

    function _pull(
        address token,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        address user
    ) private {
        IERC1155(token).safeBatchTransferFrom(user, msg.sender, tokenIds, amounts, '');
    }
}
