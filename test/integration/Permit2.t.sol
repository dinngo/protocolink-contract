// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../../src/Router.sol';
import {MockERC20} from '../mocks/MockERC20.sol';
import {PermitSignature} from "../utils/PermitSignature.sol";
import {ISignatureTransfer} from '../../src/interfaces/permit2/ISignatureTransfer.sol';
import {EIP712} from 'permit2/EIP712.sol';

contract Permit2Test is Test, PermitSignature {
    using SafeERC20 for IERC20;

    ISignatureTransfer public constant permit2 = ISignatureTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    uint256 public constant BPS_BASE = 10_000;

    address public user;
    address public user2;
    uint256 public userPrivateKey;
    bytes32 public DOMAIN_SEPARATOR;
    IERC20 public mockERC20;
    IRouter public router;

    // Empty arrays
    address[] tokensReturnEmpty;
    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('user');
        user2 = makeAddr('user2');

        router = new Router();
        mockERC20 = new MockERC20('Mock ERC20', 'mERC20');
        DOMAIN_SEPARATOR = EIP712(address(permit2)).DOMAIN_SEPARATOR();

        // User approved permit2
        vm.startPrank(user);
        mockERC20.safeApprove(address(permit2), type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), 'Router');
        vm.label(address(permit2), 'permit2');
    }

    function testPermitTransfer() external {
        IERC20 tokenIn = mockERC20;
        IERC20 tokenOut = mockERC20;
        uint256 amount = 10 ** 18;
        deal(address(tokenIn), user, amount);

        // create signed permit
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 100;
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(tokenIn), amount: amount}),
            nonce: nonce,
            deadline: deadline
        });
        bytes memory sig = getPermitTransferSignature(permit, address(router), userPrivateKey, DOMAIN_SEPARATOR);

        // create transfer details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({to: address(router), requestedAmount: amount});

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(permit2), // to
            // abi.encodeWithSelector(permit2.permitTransferFrom.selector, permit, transferDetails, user, sig),
            abi.encodeWithSignature("permitTransferFrom(((address,uint256),uint256,uint256),(address,uint256),address,bytes)", permit, transferDetails, user, sig),
            inputsEmpty,
            outputsEmpty,
            address(0) // callback
        );

        // Encode execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user2);    // take the sig will transfer to other user
        router.execute(logics, tokensReturn);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertGt(tokenOut.balanceOf(address(user2)), 0);
    }

    function testpermitWitnessTransferFrom() external {
        IERC20 tokenIn = mockERC20;
        IERC20 tokenOut = mockERC20;
        uint256 amount = 10 ** 18;
        deal(address(tokenIn), user, amount);

        // create signed permit
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 100;
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(tokenIn), amount: amount}),
            nonce: nonce,
            deadline: deadline
        });
        bytes memory sig = getPermitTransferSignature(permit, address(router), userPrivateKey, DOMAIN_SEPARATOR);

        // create transfer details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({to: address(router), requestedAmount: amount});

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = IRouter.Logic(
            address(permit2), // to
            // abi.encodeWithSelector(permit2.permitTransferFrom.selector, permit, transferDetails, user, sig),
            abi.encodeWithSignature("permitTransferFrom(((address,uint256),uint256,uint256),(address,uint256),address,bytes)", permit, transferDetails, user, sig),
            inputsEmpty,
            outputsEmpty,
            address(0) // callback
        );

        // Encode execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user2);    // take the sig will transfer to other user
        router.execute(logics, tokensReturn);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertGt(tokenOut.balanceOf(address(user2)), 0);
    }
}
