// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

interface IComet {
    struct AssetInfo {
        uint8 offset;
        address asset;
        address priceFeed;
        uint64 scale;
        uint64 borrowCollateralFactor;
        uint64 liquidateCollateralFactor;
        uint64 liquidationFactor;
        uint128 supplyCap;
    }

    function supply(address asset, uint amount) external;

    function withdraw(address asset, uint amount) external;
}
