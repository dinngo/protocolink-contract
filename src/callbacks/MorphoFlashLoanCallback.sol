// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IAgent} from '../interfaces/IAgent.sol';
import {DataType} from '../libraries/DataType.sol';
import {IRouter} from '../interfaces/IRouter.sol';
import {IMorphoFlashLoanCallback} from '../interfaces/callbacks/IMorphoFlashLoanCallback.sol';
import {IMorpho} from '../interfaces/morphoblue/IMorpho.sol';
import {ApproveHelper} from '../libraries/ApproveHelper.sol';
import {FeeLibrary} from '../libraries/FeeLibrary.sol';
import {CallbackFeeBase} from './CallbackFeeBase.sol';

import {console2} from 'forge-std/console2.sol';

/// @title Morpho flash loan callback
/// @notice flow: the current user's agent -> callback.flashloan -> Morpho -> callback.onMorphoFlashLoan -> the current user's agent
contract MorphoFlashLoanCallback is IMorphoFlashLoanCallback, CallbackFeeBase {
    using SafeERC20 for IERC20;
    using Address for address;
    using FeeLibrary for DataType.Fee;

    address public immutable router;
    address public immutable morpho;
    bytes32 internal constant _META_DATA = bytes32(bytes('morpho:flash-loan'));

    constructor(address router_, address morpho_, uint256 feeRate_) CallbackFeeBase(feeRate_, _META_DATA) {
        router = router_;
        morpho = morpho_;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external {
        IMorpho(morpho).flashLoan(token, assets, abi.encode(token, data));
    }

    /// @dev No need to check if `initiator` is the agent as it's certain when the below conditions are satisfied:
    ///      1. The callback address set in agent is this callback, i.e, the user signed a correct `callback`
    ///      2. The `msg.sender` of this callback is Morpho contract
    ///      3. The Morpho contract is benign
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        if (msg.sender != morpho) revert InvalidCaller();

        bool charge;
        uint256 initBalance;
        (address token, bytes memory userData) = abi.decode(data, (address, bytes));

        {
            (, address agent) = IRouter(router).getCurrentUserAgent();
            charge = feeRate > 0 && IAgent(agent).isCharging();

            initBalance = IERC20(token).balanceOf(address(this));

            // Transfer token to the agent and record initial balances
            IERC20(token).safeTransfer(agent, assets);

            agent.functionCall(
                abi.encodePacked(IAgent.executeByCallback.selector, userData),
                'ERROR_MORPHO_FLASH_LOAN_CALLBACK'
            );
        }

        // Repay tokens to Vault
        if (charge) {
            bytes32 defaultReferral = IRouter(router).defaultReferral();
            DataType.Fee memory fee = FeeLibrary.calcFee(token, assets, feeRate, metadata);
            fee.pay(defaultReferral);
        }

        // Check balance is valid
        if (IERC20(token).balanceOf(address(this)) != initBalance) revert InvalidBalance(token);

        // Save gas by only the first user does approve. It's safe since this callback don't hold any asset
        ApproveHelper.approveMax(token, morpho, assets);
    }
}
