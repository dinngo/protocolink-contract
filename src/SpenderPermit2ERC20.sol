// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRouter} from './interfaces/IRouter.sol';
import {ISpenderPermit2ERC20, ISignatureTransfer, IAllowanceTransfer} from './interfaces/ISpenderPermit2ERC20.sol';

/// @title Spender for permit ERC20 token where users can permit use amount
contract SpenderPermit2ERC20 is ISpenderPermit2ERC20 {
    address public immutable router;
    address public immutable permit2;

    constructor(address router_, address permit2_) {
        router = router_;
        permit2 = permit2_;
    }

    /// @notice Router asks to permit transfer tokens from the user
    /// @dev Router must guarantee that the public user is msg.sender who called Router.
    function permitPullToken(
        ISignatureTransfer.PermitTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external {
        if (msg.sender != router) revert InvalidRouter();
        address user = IRouter(router).user();

        if (transferDetails.to != router) revert InvalidTransferTo();

        ISignatureTransfer(permit2).permitTransferFrom(permit, transferDetails, user, signature);
    }

    function permitPullTokens(
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails[] calldata transferDetails,
        bytes calldata signature
    ) external {
        if (msg.sender != router) revert InvalidRouter();
        address user = IRouter(router).user();

        uint256 permittedLength = permit.permitted.length;
        for (uint256 i = 0; i < permittedLength; ) {
            if (transferDetails[i].to != router) revert InvalidTransferTo();
            unchecked {
                ++i;
            }
        }

        ISignatureTransfer(permit2).permitTransferFrom(permit, transferDetails, user, signature);
    }

    function permitToken(IAllowanceTransfer.PermitSingle memory permitSingle, bytes calldata signature) external {
        if (msg.sender != router) revert InvalidRouter();
        address user = IRouter(router).user();

        if (permitSingle.spender != address(this)) revert InvalidSpender();

        IAllowanceTransfer(permit2).permit(user, permitSingle, signature);
    }

    function permitTokens(IAllowanceTransfer.PermitBatch memory permitBatch, bytes calldata signature) external {
        if (msg.sender != router) revert InvalidRouter();
        address user = IRouter(router).user();

        uint256 permittedLength = permitBatch.details.length;
        for (uint256 i = 0; i < permittedLength; ) {
            if (permitBatch.spender != address(this)) revert InvalidSpender();
            unchecked {
                ++i;
            }
        }

        IAllowanceTransfer(permit2).permit(user, permitBatch, signature);
    }

    function pullToken(address token, uint160 amount) external {
        if (msg.sender != router) revert InvalidRouter();
        address user = IRouter(router).user();

        IAllowanceTransfer(permit2).transferFrom(user, router, amount, token);
    }

    function pullTokens(IAllowanceTransfer.AllowanceTransferDetails[] calldata transferDetails) external {
        if (msg.sender != router) revert InvalidRouter();
        address user = IRouter(router).user();

        uint256 detailsLength = transferDetails.length;
        for (uint256 i = 0; i < detailsLength; ) {
            if (transferDetails[i].from != user) revert InvalidTransferFrom();
            if (transferDetails[i].to != router) revert InvalidTransferTo();
            unchecked {
                i++;
            }
        }

        IAllowanceTransfer(permit2).transferFrom(transferDetails);
    }
}
