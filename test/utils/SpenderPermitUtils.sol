// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {SpenderPermit2ERC20, ISpenderPermit2ERC20, ISignatureTransfer, IAllowanceTransfer} from '../../src/SpenderPermit2ERC20.sol';
import {PermitSignature} from './PermitSignature.sol';
import {EIP712} from 'permit2/EIP712.sol';

contract SpenderPermitUtils is Test, PermitSignature {
    using SafeERC20 for IERC20;

    address internal constant permit2Addr = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    ISpenderPermit2ERC20 public spender;

    address private _user;
    uint256 private _userPrivateKey;
    IRouter private _router;
    bytes32 DOMAIN_SEPARATOR;

    function spenderSetUp(address user_, uint256 userPrivateKey_, IRouter router_) internal {
        _user = user_;
        _userPrivateKey = userPrivateKey_;
        _router = router_;
        spender = new SpenderPermit2ERC20(address(router_), permit2Addr);
        DOMAIN_SEPARATOR = EIP712(permit2Addr).DOMAIN_SEPARATOR();
    }

    function permitToken(IERC20 token) internal {
        // Approve token to permit2
        vm.startPrank(_user);
        token.safeApprove(permit2Addr, type(uint256).max);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = logicSpenderPermit2ERC20PermitToken(token);

        // Encode execute
        address[] memory tokensReturnEmpty;
        _router.execute(logics, tokensReturnEmpty);
        vm.stopPrank();
    }

    function logicSpenderPermit2ERC20PermitToken(IERC20 token) internal view returns (IRouter.Logic memory) {
        // Create signed permit
        uint48 defaultNonce = 0;
        uint48 defaultExpiration = uint48(block.timestamp + 5);
        IAllowanceTransfer.PermitSingle memory permit = defaultERC20PermitAllowance(
            address(token),
            type(uint160).max,
            address(spender),
            defaultExpiration,
            defaultNonce
        );
        bytes memory sig = getPermitSignature(permit, _userPrivateKey, DOMAIN_SEPARATOR);

        IRouter.Input[] memory inputsEmpty;
        IRouter.Output[] memory outputsEmpty;
        return
            IRouter.Logic(
                address(permit2Addr), // to
                abi.encodeWithSignature(
                    'permit(address,((address,uint160,uint48,uint48),address,uint256),bytes)',
                    _user,
                    permit,
                    sig
                ),
                inputsEmpty,
                outputsEmpty,
                address(0) // callback
            );
    }

    function logicSpenderPermit2ERC20PullToken(
        IERC20 token,
        uint160 amount
    ) internal view returns (IRouter.Logic memory) {
        IRouter.Input[] memory inputsEmpty;
        IRouter.Output[] memory outputsEmpty;

        return
            IRouter.Logic(
                address(spender), // to
                abi.encodeWithSelector(spender.pullToken.selector, address(token), amount),
                inputsEmpty,
                outputsEmpty,
                address(0) // callback
            );
    }
}
