// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Spender.sol";
import "./interfaces/IRouter.sol";
import "./libraries/ApproveHelper.sol";

import "forge-std/Test.sol";

contract Router is IRouter {
    using SafeERC20 for IERC20;

    Spender public immutable spender;

    constructor() {
        spender = new Spender(address(this));
    }

    /// @notice Router calls spender to pull user's tokens
    function execute(
        uint256[] calldata amountsIn,
        address[] calldata tokensOut,
        uint256[] calldata amountsOutMin,
        Logic[] calldata logics
    ) external {
        require(tokensOut.length == amountsOutMin.length, "UNEQUAL_LENGTH_0");

        // Read spender into memory to save gas
        Spender _spender = spender;

        // Pull tokensIn which is defined in the first logic
        require(logics.length > 0, "LOGICS_LENGTH");
        address[] memory tokensIn = logics[0].tokensIn;
        require(tokensIn.length == amountsIn.length, "UNEQUAL_LENGTH_1");
        for (uint256 i = 0; i < tokensIn.length; i++) {
            _spender.transferFromERC20(msg.sender, tokensIn[i], amountsIn[i]);
        }

        // Execute each logic
        for (uint256 i = 0; i < logics.length; i++) {
            address to = logics[i].to;
            bytes memory data = logics[i].data;

            // Replace token amount in data with current token balance
            for (uint256 j = 0; j < logics[i].tokensIn.length; j++) {
                require(logics[i].tokensIn.length == logics[i].amountsInOffset.length, "UNEQUAL_LENGTH_2");

                address token = logics[i].tokensIn[j];
                uint256 offset = logics[i].amountsInOffset[j];
                uint256 amount = IERC20(token).balanceOf(address(this));
                assembly {
                    let loc := add(add(data, 0x24), offset) // 0x24 = 0x20(length) + 0x4(sig)
                    mstore(loc, amount)
                }

                // Approve token
                ApproveHelper._tokenApprove(token, to, type(uint256).max);
            }

            // Execute
            require(to != address(_spender), "SPENDER");
            (bool success,) = to.call(data);
            require(success, "FAIL");

            // Reset approval
            for (uint256 j = 0; j < logics[i].tokensIn.length; j++) {
                address token = logics[i].tokensIn[j];
                ApproveHelper._tokenApproveZero(token, to);
            }
        }

        // Push tokensOut if any balance and check minimal amount
        for (uint256 i = 0; i < tokensOut.length; i++) {
            uint256 balance = IERC20(tokensOut[i]).balanceOf(address(this));
            require(balance >= amountsOutMin[i], "AMOUNT_OUT");

            if (balance > 0) {
                IERC20(tokensOut[i]).safeTransfer(msg.sender, balance);
            }
        }

        // Push tokensIn if any balance
        for (uint256 i = 0; i < tokensIn.length; i++) {
            uint256 balance = IERC20(tokensIn[i]).balanceOf(address(this));
            if (balance > 0) {
                IERC20(tokensIn[i]).safeTransfer(msg.sender, balance);
            }
        }
    }
}
