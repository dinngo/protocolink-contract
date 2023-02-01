// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {ISpenderPermit2ERC20} from './interfaces/ISpenderPermit2ERC20.sol';
import {ISignatureTransfer} from './interfaces/permit2/ISignatureTransfer.sol';

/// @title Spender for permit ERC20 token where users can permit use amount
contract SpenderPermit2ERC20 is ISpenderPermit2ERC20 {
    using SafeERC20 for IERC20;

    address public immutable router;
    address public immutable permit2;

    constructor(address router_, address permit2_) {
        router = router_;
        permit2 = permit2_;
    }

    /// @notice Router asks to permit transfer tokens from the user
    /// @dev Router must guarantee that the public user is msg.sender who called Router.
    function permitPullToken(address token, uint256 amount, uint256 nonce, uint256 deadline, bytes calldata signature) external {
        if (msg.sender != router) revert InvalidRouter();
        address user = IRouter(router).user();

        _permitPull(token, amount, user, nonce, deadline, signature);
    }

    function permitPullTokens(address[] calldata tokens, uint256[] calldata amounts, uint256 nonce, uint256 deadline, bytes calldata signature) external {
        if (msg.sender != router) revert InvalidRouter();
        address user = IRouter(router).user();

        _permitPullTokens(tokens, amounts, user, nonce, deadline, signature);
    }

    function _permitPull(address token, uint256 amount, address user, uint256 nonce, uint256 deadline, bytes calldata signature) private {
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: token, amount: amount}),
            nonce: nonce,
            deadline: deadline
        });
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({to: router, requestedAmount: amount});
        ISignatureTransfer(permit2).permitTransferFrom(permit, transferDetails, user, signature);
    }

    function _permitPullTokens(address[] calldata tokens, uint256[] calldata amounts, address user, uint256 nonce, uint256 deadline, bytes calldata signature) private {
        uint256 tokensLength = tokens.length;
        if (tokensLength != amounts.length) revert LengthMismatch();
        ISignatureTransfer.TokenPermissions[] memory permitted = new ISignatureTransfer.TokenPermissions[](tokensLength);
        ISignatureTransfer.SignatureTransferDetails[] memory transferDetails = new ISignatureTransfer.SignatureTransferDetails[](tokensLength);
        for (uint256 i = 0; i < tokensLength; ) {
            permitted[i] = ISignatureTransfer.TokenPermissions({token: tokens[i], amount: amounts[i]});
            transferDetails[i] = ISignatureTransfer.SignatureTransferDetails({to: router, requestedAmount: amounts[i]});
            unchecked {
                i++;
            }
        }
        ISignatureTransfer.PermitBatchTransferFrom memory permit = ISignatureTransfer.PermitBatchTransferFrom({
            permitted: permitted,
            nonce: nonce,
            deadline: deadline
        });
        ISignatureTransfer(permit2).permitTransferFrom(permit, transferDetails, user, signature);
    }
}
