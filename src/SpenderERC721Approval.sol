// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {ISpenderERC721Approval} from './interfaces/ISpenderERC721Approval.sol';

/// @title Spender for ERC721 token approval where users can approve the collection
contract SpenderERC721Approval is ISpenderERC721Approval {
    address public immutable router;

    constructor(address router_) {
        router = router_;
    }

    /// @notice Router asks to transfer tokens from the user
    /// @dev Router must guarantee that the public user is msg.sender who called Router.
    function pullToken(address token, uint256 tokenId) external {
        (address user, address agent) = IRouter(router).getUserAgent();
        if (msg.sender != agent) revert InvalidAgent();

        _pull(token, tokenId, user);
    }

    function pullTokens(address[] calldata tokens, uint256[] calldata tokenIds) external {
        (address user, address agent) = IRouter(router).getUserAgent();
        if (msg.sender != agent) revert InvalidAgent();

        uint256 tokensLength = tokens.length;
        if (tokensLength != tokenIds.length) revert LengthMismatch();
        for (uint256 i = 0; i < tokensLength; ) {
            _pull(tokens[i], tokenIds[i], user);

            unchecked {
                ++i;
            }
        }
    }

    function _pull(
        address token,
        uint256 tokenId,
        address user
    ) private {
        IERC721(token).safeTransferFrom(user, msg.sender, tokenId);
    }
}
