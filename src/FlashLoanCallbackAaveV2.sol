// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20, Address} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {IFlashLoanCallbackAaveV2} from "./interfaces/IFlashLoanCallbackAaveV2.sol";
import {IAaveV2Provider} from "./interfaces/aaveV2/IAaveV2Provider.sol";
import {ApproveHelper} from "./libraries/ApproveHelper.sol";

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

    function executeOperation(
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory premiums,
        address initiator,
        bytes memory params
    ) external returns (bool) {
        address pool = IAaveV2Provider(aaveV2Provider).getLendingPool();

        // TODO: are these checks redundant?
        if (msg.sender != pool) revert InvalidCaller();
        if (initiator != router) revert InvalidInitiator();

        // Transfer assets to Router
        uint256 assetsLength = assets.length;
        for (uint256 i = 0; i < assetsLength;) {
            IERC20(assets[i]).safeTransfer(router, amounts[i]);

            unchecked {
                i++;
            }
        }

        // Call Router::executeByCallback
        // TODO: is needed to check func sig?
        router.functionCall(params, "ERROR_AAVE_V2_FLASH_LOAN_CALLBACK");

        // Approve assets for Pool pulling
        for (uint256 i = 0; i < assetsLength;) {
            uint256 amountOwing = amounts[i] + premiums[i];
            // TODO: is max approval safe?
            ApproveHelper._approveMax(assets[i], pool, amountOwing);

            unchecked {
                i++;
            }
        }

        return true;
    }
}
