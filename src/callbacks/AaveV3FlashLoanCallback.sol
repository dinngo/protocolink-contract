// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAgent} from '../interfaces/IAgent.sol';
import {DataType} from '../libraries/DataType.sol';
import {IRouter} from '../interfaces/IRouter.sol';
import {IAaveV3FlashLoanCallback} from '../interfaces/callbacks/IAaveV3FlashLoanCallback.sol';
import {IAaveV3Provider} from '../interfaces/aaveV3/IAaveV3Provider.sol';
import {ApproveHelper} from '../libraries/ApproveHelper.sol';
import {FeeLibrary} from '../libraries/FeeLibrary.sol';
import {CallbackFeeBase} from './CallbackFeeBase.sol';

/// @title Aave V3 flash loan callback
/// @notice Invoked by Aave V3 pool to call the current user's agent
contract AaveV3FlashLoanCallback is IAaveV3FlashLoanCallback, CallbackFeeBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using FeeLibrary for DataType.Fee;

    address public immutable router;
    address public immutable aaveV3Provider;
    bytes32 internal constant _META_DATA = bytes32(bytes('aave-v3:flash-loan'));

    constructor(address router_, address aaveV3Provider_, uint256 feeRate_) CallbackFeeBase(feeRate_, _META_DATA) {
        router = router_;
        aaveV3Provider = aaveV3Provider_;
    }

    /// @dev No need to check if `initiator` is the agent as it's certain when the below conditions are satisfied:
    ///      1. The `to` address used in agent is Aave Pool, i.e, the user signed a correct `to`
    ///      2. The callback address set in agent is this callback, i.e, the user signed a correct `callback`
    ///      3. The `msg.sender` of this callback is Aave Pool
    ///      4. The Aave pool is benign
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address, // initiator
        bytes calldata params
    ) external returns (bool) {
        address pool = IAaveV3Provider(aaveV3Provider).getPool();
        if (msg.sender != pool) revert InvalidCaller();
        bool charge;
        uint256[] memory initBalances = new uint256[](assets.length);
        {
            (, address agent) = IRouter(router).getCurrentUserAgent();
            charge = feeRate > 0 && IAgent(agent).isCharging();

            // Transfer assets to the agent and record initial balances
            for (uint256 i; i < assets.length; ) {
                address asset = assets[i];
                IERC20(asset).safeTransfer(agent, amounts[i]);
                initBalances[i] = IERC20(asset).balanceOf(address(this));

                unchecked {
                    ++i;
                }
            }

            agent.functionCall(
                abi.encodePacked(IAgent.executeByCallback.selector, params),
                'ERROR_AAVE_V3_FLASH_LOAN_CALLBACK'
            );
        }

        // Approve assets for pulling from Aave Pool
        for (uint256 i; i < assets.length; ) {
            address asset = assets[i];
            uint256 amount = amounts[i];
            uint256 amountOwing = amount + premiums[i];

            if (charge) {
                bytes32 defaultReferral = IRouter(router).defaultReferral();
                DataType.Fee memory fee = FeeLibrary.calcFee(asset, amount, feeRate, metadata);
                fee.pay(defaultReferral);
            }

            // Check balance is valid
            if (IERC20(asset).balanceOf(address(this)) != initBalances[i] + amountOwing) revert InvalidBalance(asset);

            // Save gas by only the first user does approve. It's safe since this callback don't hold any asset
            ApproveHelper.approveMax(asset, pool, amountOwing);

            unchecked {
                ++i;
            }
        }

        return true;
    }
}
