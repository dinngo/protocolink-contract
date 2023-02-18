// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IRouter} from './interfaces/IRouter.sol';
import {ISpenderAaveV2Delegation} from './interfaces/ISpenderAaveV2Delegation.sol';
import {IAaveV2Provider} from './interfaces/aaveV2/IAaveV2Provider.sol';
import {IAaveV2Pool} from './interfaces/aaveV2/IAaveV2Pool.sol';

/// @title Spender for Aave V2 credit delegation where users can approve max delegation
contract SpenderAaveV2Delegation is ISpenderAaveV2Delegation {
    using SafeERC20 for IERC20;

    uint16 private constant _REFERRAL_CODE = 56;

    address public immutable router;
    address public immutable aaveV2Provider;

    modifier isAgent() {
        if (msg.sender != IRouter(router).getAgent()) revert InvalidAgent();
        _;
    }

    constructor(address router_, address aaveV2Provider_) {
        router = router_;
        aaveV2Provider = aaveV2Provider_;
    }

    /// @notice Router asks to borrow tokens using the user's delegation
    /// @dev Router must guarantee that the public user is msg.sender who called Router.
    function borrow(address asset, uint256 amount, uint256 interestRateMode) external isAgent {
        address user = IRouter(router).user();

        address pool = IAaveV2Provider(aaveV2Provider).getLendingPool();
        IAaveV2Pool(pool).borrow(asset, amount, interestRateMode, _REFERRAL_CODE, user);

        IERC20(asset).safeTransfer(msg.sender, IERC20(asset).balanceOf(address(this)));
    }
}
