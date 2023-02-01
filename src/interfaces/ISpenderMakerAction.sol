// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISpenderMakerAction {
    error InvalidRouter();

    error ActionFail(bytes4 sig, string reason);

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

    function safeLockETH(uint256 value, address ethJoin, uint256 cdp) external payable;

    function safeLockGem(address gemJoin, uint256 cdp, uint256 wad) external;

    function freeETH(address ethJoin, uint256 cdp, uint256 wad) external;

    function freeGem(address gemJoin, uint256 cdp, uint256 wad) external;

    function draw(address daiJoin, uint256 cdp, uint256 wad) external;

    function wipe(address daiJoin, uint256 cdp, uint256 wad) external;

    function wipeAll(address daiJoin, uint256 cdp) external;
}
