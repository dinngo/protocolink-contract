// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {IFlashLoanCallbackBalancerV2} from "./interfaces/IFlashLoanCallbackBalancerV2.sol";

/// @title Balancer V2 flash loan callback
contract FlashLoanCallbackBalancerV2 is IFlashLoanCallbackBalancerV2 {
    using SafeERC20 for IERC20;
    using Address for address;

    address public immutable router;
    address public immutable balancerV2Vault;

    constructor(address router_, address balancerV2Vault_) {
        router = router_;
        balancerV2Vault = balancerV2Vault_;
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory, // feeAmounts
        bytes memory userData
    ) external {
        // TODO: is the check redundant?
        if (msg.sender != balancerV2Vault) revert InvalidCaller();

        // Transfer tokens to Router
        uint256 tokensLength = tokens.length;
        for (uint256 i = 0; i < tokensLength;) {
            IERC20(tokens[i]).safeTransfer(router, amounts[i]);

            unchecked {
                i++;
            }
        }

        // Call Router::executeByEntrant
        // TODO: is needed to check func sig?
        router.functionCall(userData, "ERROR_BALANCER_V2_FLASH_LOAN_CALLBACK");

        // Repay tokens to Vault
        for (uint256 i = 0; i < tokensLength;) {
            IERC20(tokens[i]).safeTransfer(balancerV2Vault, amounts[i]);

            unchecked {
                i++;
            }
        }
    }
}
