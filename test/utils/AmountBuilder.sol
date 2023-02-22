// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library AmountBuilder {
    function fill(uint256 length, uint256 amount) external pure returns (uint256[] memory amounts) {
        amounts = new uint256[](length);
        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = amount;
        }
    }

    function fillUInt160(uint256 length, uint160 amount) external pure returns (uint160[] memory amounts) {
        amounts = new uint160[](length);
        for (uint256 i = 0; i < length; ++i) {
            amounts[i] = amount;
        }
    }

    function push(uint256[] calldata a, uint256 b) external pure returns (uint256[] memory amounts) {
        amounts = new uint256[](a.length + 1);
        for (uint256 i = 0; i < a.length; ++i) {
            amounts[i] = a[i];
        }
        amounts[a.length] = b;
    }
}
