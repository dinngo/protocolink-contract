// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpenderMakerVaultAuthority {
    error InvalidAgent();
    error UnauthorizedSender(uint256 cdp);

    function freeETH(address ethJoin, uint256 cdp, uint256 wad) external;

    function freeGem(address gemJoin, uint256 cdp, uint256 wad) external;

    function draw(address daiJoin, uint256 cdp, uint256 wad) external;
}
