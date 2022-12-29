// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/ISpenderAaveV2Delegation.sol";
import "./interfaces/aaveV2/ILendingPoolAddressesProviderV2.sol";
import "./interfaces/aaveV2/ILendingPoolV2.sol";

/// @notice Users can approve maximal amount to this
contract SpenderAaveV2Delegation is ISpenderAaveV2Delegation {
    using SafeERC20 for IERC20;

    address public immutable router;
    address public immutable aaveV2Provider;

    uint16 private constant REFERRAL_CODE = 56;

    constructor(address router_, address aaveV2Provider_) {
        router = router_;
        aaveV2Provider = aaveV2Provider_;
    }

    /// @notice Router asks to transfer tokens from user
    /// @dev Router must guarantee that only consumes the approval of a correct user.
    function borrow(address asset, uint256 amount, uint256 interestRateMode) external {
        address _router = router;
        address user = IRouter(_router).msgSender();
        require(user != address(0), "INVALID_USER");

        address pool = ILendingPoolAddressesProviderV2(aaveV2Provider).getLendingPool();
        ILendingPoolV2(pool).borrow(asset, amount, interestRateMode, REFERRAL_CODE, user);

        IERC20(asset).safeTransfer(_router, IERC20(asset).balanceOf(address(this)));
    }
}
