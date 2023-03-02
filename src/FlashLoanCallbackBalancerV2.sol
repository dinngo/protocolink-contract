// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {IFlashLoanCallbackBalancerV2} from './interfaces/IFlashLoanCallbackBalancerV2.sol';

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
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        if (msg.sender != balancerV2Vault) revert InvalidCaller();
        address agent = IRouter(router).getAgent();

        // Transfer tokens to Router and record initial balances
        uint256 tokensLength = tokens.length;
        uint256[] memory initBalances = new uint256[](tokensLength);
        for (uint256 i = 0; i < tokensLength; ) {
            address token = tokens[i];

            IERC20(token).safeTransfer(agent, amounts[i]);
            initBalances[i] = IERC20(token).balanceOf(address(this));

            unchecked {
                ++i;
            }
        }

        // Call Agent::execute
        agent.functionCall(userData, 'ERROR_BALANCER_V2_FLASH_LOAN_CALLBACK');

        // Repay tokens to Vault
        for (uint256 i = 0; i < tokensLength; ) {
            address token = tokens[i];
            IERC20(token).safeTransfer(balancerV2Vault, amounts[i] + feeAmounts[i]);

            // Check balance is valid
            if (IERC20(token).balanceOf(address(this)) != initBalances[i]) revert InvalidBalance(token);

            unchecked {
                ++i;
            }
        }
    }
}
