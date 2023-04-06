// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {IAgent} from './interfaces/IAgent.sol';
import {IParam} from './interfaces/IParam.sol';
import {IFlashLoanCallbackAaveV2} from './interfaces/IFlashLoanCallbackAaveV2.sol';
import {IAaveV2Provider} from './interfaces/aaveV2/IAaveV2Provider.sol';
import {ApproveHelper} from './libraries/ApproveHelper.sol';

/// @title Aave V2 flash loan callback
contract FlashLoanCallbackAaveV2 is IFlashLoanCallbackAaveV2 {
    using SafeERC20 for IERC20;
    using Address for address;

    address public immutable router;
    address public immutable aaveV2Provider;

    constructor(address router_, address aaveV2Provider_) {
        router = router_;
        aaveV2Provider = aaveV2Provider_;
    }

    /// @dev No need to check whether `initiator` is Agent as it's certain when the below conditions are satisfied:
    ///      1. `to` in Agent is Aave Pool, i.e, user signed a correct `to`
    ///      2. `_callback` in Agent is set to this callback, i.e, user signed a correct `callback`
    ///      3. `msg.sender` of this callback is Aave Pool
    ///      4. Aave Pool contract is benign
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address, // initiator
        bytes calldata params
    ) external returns (bool) {
        address pool = IAaveV2Provider(aaveV2Provider).getLendingPool();

        if (msg.sender != pool) revert InvalidCaller();
        address agent = IRouter(router).getAgent();

        // Transfer assets to Agent and record initial balances
        uint256 assetsLength = assets.length;
        uint256[] memory initBalances = new uint256[](assetsLength);
        for (uint256 i = 0; i < assetsLength; ) {
            address asset = assets[i];

            IERC20(asset).safeTransfer(agent, amounts[i]);
            initBalances[i] = IERC20(asset).balanceOf(address(this));

            unchecked {
                ++i;
            }
        }

        {
            // Call Agent::execute
            (IParam.Logic[] memory logics, IParam.Fee[] memory fees, address[] memory tokensReturn) = abi.decode(
                params,
                (IParam.Logic[], IParam.Fee[], address[])
            );
            IAgent(agent).execute(logics, fees, tokensReturn);
        }

        // Approve assets for pulling from Aave Pool
        for (uint256 i = 0; i < assetsLength; ) {
            address asset = assets[i];
            uint256 amountOwing = amounts[i] + premiums[i];

            // Check balance is valid
            if (IERC20(asset).balanceOf(address(this)) != initBalances[i] + amountOwing) revert InvalidBalance(asset);

            // Save gas by only the first user does approve. It's safe since this callback don't hold any asset
            ApproveHelper._approveMax(asset, pool, amountOwing);

            unchecked {
                ++i;
            }
        }

        return true;
    }
}
