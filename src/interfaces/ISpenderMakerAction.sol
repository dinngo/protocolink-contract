// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpenderMakerAction {
    error InvalidRouter();
    error ActionFail(bytes4 sig, string reason);

    // function createDSProxy() external returns (address); // if proxy exist, skip.

    // function isDSProxyExist() external view returns (bool); // check user's (tx.origin) is exist or not

    // function openLockETHAndDraw(
    //     uint256 value,
    //     address ethJoin,
    //     address daiJoin,
    //     bytes32 ilk,
    //     uint256 wadD
    // ) external payable returns (uint256 cdp);
}
