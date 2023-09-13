// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAgent} from '../interfaces/IAgent.sol';
import {DataType} from '../libraries/DataType.sol';
import {IRouter} from '../interfaces/IRouter.sol';
import {IBalancerV2FlashLoanCallback} from '../interfaces/callbacks/IBalancerV2FlashLoanCallback.sol';
import {FeeLibrary} from '../libraries/FeeLibrary.sol';
import {CallbackFeeBase} from './CallbackFeeBase.sol';

/// @title Balancer V2 flash loan callback
/// @notice Invoked by Balancer V2 vault to call the current user's agent
contract BalancerV2FlashLoanCallback is IBalancerV2FlashLoanCallback, CallbackFeeBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using FeeLibrary for DataType.Fee;

    address public immutable router;
    address public immutable balancerV2Vault;
    bytes32 internal constant _META_DATA = bytes32(bytes('balancer-v2:flash-loan'));

    constructor(address router_, address balancerV2Vault_, uint256 feeRate_) CallbackFeeBase(feeRate_, _META_DATA) {
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
        bool charge;
        uint256 length = tokens.length;
        uint256[] memory initBalances = new uint256[](length);
        {
            (, address agent) = IRouter(router).getCurrentUserAgent();
            charge = feeRate > 0 && IAgent(agent).isCharging();

            // Transfer assets to the agent and record initial balances
            for (uint256 i; i < length; ) {
                address token = tokens[i];
                IERC20(token).safeTransfer(agent, amounts[i]);
                initBalances[i] = IERC20(token).balanceOf(address(this));

                unchecked {
                    ++i;
                }
            }

            agent.functionCall(
                abi.encodePacked(IAgent.executeByCallback.selector, userData),
                'ERROR_BALANCER_V2_FLASH_LOAN_CALLBACK'
            );
        }

        // Repay tokens to Vault
        for (uint256 i; i < length; ) {
            address token = tokens[i];
            uint256 amount = amounts[i];

            if (charge) {
                bytes32 defaultReferral = IRouter(router).defaultReferral();
                DataType.Fee memory fee = FeeLibrary.calcFee(token, amount, feeRate, metadata);
                fee.pay(defaultReferral);
            }

            IERC20(token).safeTransfer(balancerV2Vault, amount + feeAmounts[i]);

            // Check balance is valid
            if (IERC20(token).balanceOf(address(this)) != initBalances[i]) revert InvalidBalance(token);

            unchecked {
                ++i;
            }
        }
    }
}
