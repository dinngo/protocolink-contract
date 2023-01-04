// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IRouter.sol";
import "./interfaces/IFlashloanBalancerV2.sol";

/// @notice Flashloan callback
contract FlashloanBalancerV2 is IFlashloanBalancerV2 {
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
        require(msg.sender == balancerV2Vault, "INVALID_CALLER");

        // Transfer flashloaned assets to Router
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(router, amounts[i]);
        }

        // Call Router::executeUserSet
        router.functionCall(userData, "ERROR_EXECUTE_OPERATION");

        // Repay flashloaned assets to Vault
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransfer(balancerV2Vault, amounts[i]);
        }
    }
}
