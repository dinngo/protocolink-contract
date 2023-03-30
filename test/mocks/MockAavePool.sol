// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {MockERC20} from './MockERC20.sol';

interface IAaveV2Pool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;
}

contract MockAavePool is IAaveV2Pool {
    address[] public tokens;

    constructor(address[] memory tokens_) {
        tokens = tokens_;
    }

    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external {
        modes;
        onBehalfOf;
        params;
        referralCode;

        uint256 length = assets.length;
        uint256[] memory premiums = new uint256[](length);
        for (uint256 i = 0; i < length; ++i) {
            // Mint asset to `receiverAddress`
            MockERC20(assets[i]).mint(receiverAddress, amounts[i]);

            // Calculate premiums
            uint256 premium = (amounts[i] * 9) / 10000;
            premiums[i] = premium;
        }

        // Skip calling executeOperation()

        // Pull amounts + premiums
        for (uint256 i = 0; i < length; ++i) {
            IERC20(assets[i]).transferFrom(receiverAddress, address(this), amounts[i] + premiums[i]);
        }
    }

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external {
        interestRateMode;
        referralCode;
        onBehalfOf;
        MockERC20(asset).mint(msg.sender, amount);
    }
}
