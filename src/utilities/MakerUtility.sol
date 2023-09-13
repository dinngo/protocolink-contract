// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {SafeERC20, IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {IRouter} from '../interfaces/IRouter.sol';
import {IMakerUtility} from '../interfaces/utilities/IMakerUtility.sol';
import {IDSProxy, IDSProxyRegistry} from '../interfaces/maker/IDSProxy.sol';
import {IMakerGemJoin} from '../interfaces/maker/IMaker.sol';
import {ApproveHelper} from '../libraries/ApproveHelper.sol';

/// @title Maker utility contract
/// @notice Perform additional actions when interacting with Maker
contract MakerUtility is IMakerUtility {
    using SafeERC20 for IERC20;

    address public constant NATIVE_TOKEN_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable router;
    address public immutable proxyRegistry;
    address public immutable cdpManager;
    address public immutable proxyActions;
    address public immutable daiToken;
    address public immutable jug;
    // MakerUtility's DSProxy
    IDSProxy public immutable dsProxy;

    constructor(
        address router_,
        address proxyRegistry_,
        address cdpManager_,
        address proxyActions_,
        address daiToken_,
        address jug_
    ) {
        router = router_;
        proxyRegistry = proxyRegistry_;
        cdpManager = cdpManager_;
        proxyActions = proxyActions_;
        daiToken = daiToken_;
        jug = jug_;

        dsProxy = IDSProxy(IDSProxyRegistry(proxyRegistry).build());
    }

    /// @notice Creates a cdp for the user(for a specific `ilk`), deposits `value` amount of ETH in `ethJoin`
    /// and exits `wad` amount of DAI token from `daiJoin` adapter.
    function openLockETHAndDraw(
        uint256 value,
        address ethJoin,
        address daiJoin,
        bytes32 ilk,
        uint256 wadD
    ) external payable returns (uint256 cdp) {
        (address user, address agent) = IRouter(router).getCurrentUserAgent();
        if (msg.sender != agent) revert InvalidAgent();

        bytes32 ret = dsProxy.execute{value: value}(
            proxyActions,
            abi.encodeWithSelector(
                0xe685cc04, // selector of "openLockETHAndDraw(address,address,address,address,bytes32,uint256)"
                cdpManager,
                jug,
                ethJoin,
                daiJoin,
                ilk,
                wadD
            )
        );
        cdp = uint256(ret);

        IERC20(daiToken).safeTransfer(agent, wadD);
        _transferCdp(user, cdp);
    }

    /// @notice Creates a cdp for the user(for a specific `ilk`), deposits `wadC` amount of collateral in `gemJoin`
    /// and exits `wadD` amount of DAI token from `daiJoin` adapter.
    function openLockGemAndDraw(
        address gemJoin,
        address daiJoin,
        bytes32 ilk,
        uint256 wadC,
        uint256 wadD
    ) external returns (uint256 cdp) {
        (address user, address agent) = IRouter(router).getCurrentUserAgent();
        if (msg.sender != agent) revert InvalidAgent();

        // Get collateral token
        address token = IMakerGemJoin(gemJoin).gem();
        ApproveHelper.approveMax(token, address(dsProxy), wadC);

        bytes32 ret = dsProxy.execute(
            proxyActions,
            abi.encodeWithSelector(
                0xdb802a32, // selector of "openLockGemAndDraw(address,address,address,address,bytes32,uint256,uint256,bool)"
                cdpManager,
                jug,
                gemJoin,
                daiJoin,
                ilk,
                wadC,
                wadD,
                true
            )
        );
        cdp = uint256(ret);

        IERC20(daiToken).safeTransfer(agent, wadD);
        _transferCdp(user, cdp);
    }

    function _transferCdp(address user, uint256 cdp) internal {
        dsProxy.execute(
            proxyActions,
            abi.encodeWithSelector(
                0x493c2049, // selector of "giveToProxy(address,address,uint256,address)"
                proxyRegistry,
                cdpManager,
                cdp,
                user
            )
        );
    }
}
