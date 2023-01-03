// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IFlashloanAaveV2.sol";
import "./interfaces/aaveV2/ILendingPoolAddressesProviderV2.sol";
import "./libraries/ApproveHelper.sol";

/// @notice Flashloan callback
contract FlashloanAaveV2 is IFlashloanAaveV2 {
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
        address pool = ILendingPoolAddressesProviderV2(aaveV2Provider).getLendingPool();

        // TODO: are these checks redundant?
        require(msg.sender == pool, "INVALID_CALLER");
        require(initiator == router, "INVALID_INITIATOR");

        // Transfer flashloaned assets to Router
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20(assets[i]).safeTransfer(router, amounts[i]);
        }

        // Call Router::executeUserSet
        router.functionCall(params, "ERROR_EXECUTE_OPERATION");

        for (uint256 i = 0; i < assets.length; i++) {
            uint256 amountOwing = amounts[i] + premiums[i];
            ApproveHelper._tokenApproveMax(assets[i], pool, amountOwing);
        }

        return true;
    }
}
