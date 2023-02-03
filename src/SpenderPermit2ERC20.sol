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
    function permitPullToken(ISignatureTransfer.PermitTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails calldata transferDetails, bytes calldata signature) external {
        if (msg.sender != router) revert InvalidRouter();
        address user = IRouter(router).user();

        if (transferDetails.to != router) revert InvalidTransferTo();

        ISignatureTransfer(permit2).permitTransferFrom(permit, transferDetails, user, signature);
    }

    function permitPullTokens(ISignatureTransfer.PermitBatchTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails[] calldata transferDetails, bytes calldata signature) external {
        if (msg.sender != router) revert InvalidRouter();
        address user = IRouter(router).user();

        uint256 numPermitted = permit.permitted.length;
        if (numPermitted != transferDetails.length) revert LengthMismatch(); // permitTransferFrom will check length again

        for (uint256 i = 0; i < numPermitted; ){
            if (transferDetails[i].to != router) revert InvalidTransferTo();
            unchecked { ++i; }
        }

        ISignatureTransfer(permit2).permitTransferFrom(permit, transferDetails, user, signature);
    }
}
