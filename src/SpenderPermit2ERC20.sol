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
        ISignatureTransfer.PermitTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails calldata transferDetails,
        bytes calldata signature
    ) external {
        (address user, address agent) = IRouter(router).getUserAgent();
        if (msg.sender != agent) revert InvalidAgent();

        if (transferDetails.to != msg.sender) revert InvalidTransferTo();

        ISignatureTransfer(permit2).permitTransferFrom(permit, transferDetails, user, signature);
    }

    function permitPullTokens(
        ISignatureTransfer.PermitBatchTransferFrom calldata permit,
        ISignatureTransfer.SignatureTransferDetails[] calldata transferDetails,
        bytes calldata signature
    ) external {
        (address user, address agent) = IRouter(router).getUserAgent();
        if (msg.sender != agent) revert InvalidAgent();

        uint256 permittedLength = permit.permitted.length;
        for (uint256 i = 0; i < permittedLength; ) {
            if (transferDetails[i].to != msg.sender) revert InvalidTransferTo();
            unchecked {
                ++i;
            }
        }

        ISignatureTransfer(permit2).permitTransferFrom(permit, transferDetails, user, signature);
    }

    function pullToken(address token, uint160 amount) external {
        (address user, address agent) = IRouter(router).getUserAgent();
        if (msg.sender != agent) revert InvalidAgent();

        IAllowanceTransfer(permit2).transferFrom(user, msg.sender, amount, token);
    }

    function pullTokens(IAllowanceTransfer.AllowanceTransferDetails[] calldata transferDetails) external {
        (address user, address agent) = IRouter(router).getUserAgent();
        if (msg.sender != agent) revert InvalidAgent();

        uint256 detailsLength = transferDetails.length;
        for (uint256 i = 0; i < detailsLength; ) {
            if (transferDetails[i].from != user) revert InvalidTransferFrom();
            if (transferDetails[i].to != msg.sender) revert InvalidTransferTo();
            unchecked {
                ++i;
            }
        }

        IAllowanceTransfer(permit2).transferFrom(transferDetails);
    }
}
