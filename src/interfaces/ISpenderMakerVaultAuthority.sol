// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpenderMakerVaultAuthority {
    error InvalidRouter();
    error ActionFail(bytes4 sig, string reason);
    error UnauthorizedSender(uint256 cdp);

    function openLockETHAndDraw(
        uint256 value,
        address ethJoin,
        address daiJoin,
        bytes32 ilk,
        uint256 wadD
    ) external payable returns (uint256 cdp);

    function openLockGemAndDraw(
        address gemJoin,
        address daiJoin,
        bytes32 ilk,
        uint256 wadC,
        uint256 wadD
    ) external returns (uint256 cdp);

    function freeETH(address ethJoin, uint256 cdp, uint256 wad) external;

    function freeGem(address gemJoin, uint256 cdp, uint256 wad) external;

    function draw(address daiJoin, uint256 cdp, uint256 wad) external;
}
