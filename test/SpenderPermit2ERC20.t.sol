// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {Router, IRouter} from '../src/Router.sol';
import {SpenderPermit2ERC20, ISpenderPermit2ERC20, ISignatureTransfer, IAllowanceTransfer} from '../src/SpenderPermit2ERC20.sol';
import {MockERC20} from './mocks/MockERC20.sol';
import {PermitSignature} from "./utils/PermitSignature.sol";
import {EIP712} from 'permit2/EIP712.sol';

contract SpenderPermit2ERC20Test is Test, PermitSignature {
    using SafeERC20 for IERC20;

    address public constant permit2Addr = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    uint256 public constant defaultSignatureAmount = 10 ** 18;
    uint160 public constant defaultAllowanceAmount = 10 ** 18;
    uint48 public constant defaultNonce = 0;
    uint48 public defaultExpiration = uint48(block.timestamp + 5);

    address public user;
    uint256 public userPrivateKey;

    IRouter public router;
    ISpenderPermit2ERC20 public spender;
    IERC20 public mockERC20;

    IRouter.Input[] inputsEmpty;
    IRouter.Output[] outputsEmpty;
    address[] tokensReturnEmpty;

    bytes32 DOMAIN_SEPARATOR;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');

        router = new Router();
        spender = new SpenderPermit2ERC20(address(router), permit2Addr);
        mockERC20 = new MockERC20('Mock ERC20', 'mERC20');
        DOMAIN_SEPARATOR = EIP712(permit2Addr).DOMAIN_SEPARATOR();

        // User approved spender and permit2
        vm.startPrank(user);
        mockERC20.safeApprove(address(spender), type(uint256).max);
        mockERC20.safeApprove(permit2Addr, type(uint256).max);
        vm.stopPrank();

        vm.label(address(router), 'Router');
        vm.label(address(spender), 'SpenderPermit2ERC20');
        vm.label(address(mockERC20), 'mERC20');
        vm.label(permit2Addr, 'Permit2');
    }

    function testPermitPullToken(uint256 amountIn) external {
        IERC20 tokenIn = mockERC20;
        IERC20 tokenOut = mockERC20;
        amountIn = bound(amountIn, 1e1, 1e12);
        deal(address(tokenIn), user, amountIn);

        // Create signed permit
        uint256 nonce = 0;
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(address(tokenIn), nonce);
        permit.permitted.amount = amountIn;
        bytes memory sig = getPermitTransferSignature(permit, address(spender), userPrivateKey, DOMAIN_SEPARATOR);

        // Create transfer details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({to: address(router), requestedAmount: amountIn});

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitPullToken(permit, transferDetails, sig);

        // Encode execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertGt(tokenOut.balanceOf(address(user)), 0);
    }

    function testPermitPullTokenInvalidUser() external {
        IERC20 tokenIn = mockERC20;
        IERC20 tokenOut = mockERC20;
        deal(address(tokenIn), user, defaultSignatureAmount);

        // Create signed permit
        uint256 nonce = 0;
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(address(tokenIn), nonce);
        bytes memory sig = getPermitTransferSignature(permit, address(spender), userPrivateKey, DOMAIN_SEPARATOR);

        // Create transfer details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({to: address(router), requestedAmount: defaultSignatureAmount});

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitPullToken(permit, transferDetails, sig);

        // Encode execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);

        vm.expectRevert("ERROR_ROUTER_EXECUTE");
        router.execute(logics, tokensReturn);
    }

     function testPermitPullTokenInvalidTransferTo() external {
        IERC20 tokenIn = mockERC20;
        IERC20 tokenOut = mockERC20;
        deal(address(tokenIn), user, defaultSignatureAmount);

        // Create signed permit
        uint256 nonce = 0;
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(address(tokenIn), nonce);
        bytes memory sig = getPermitTransferSignature(permit, address(spender), userPrivateKey, DOMAIN_SEPARATOR);

        // Create transfer details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: defaultSignatureAmount});

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitPullToken(permit, transferDetails, sig);

        // Encode execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);

        vm.expectRevert(ISpenderPermit2ERC20.InvalidTransferTo.selector);
        router.execute(logics, tokensReturn);
    }

    function testPermitPullTokens(uint256 amountIn) external {
        IERC20 tokenIn = mockERC20;
        IERC20 tokenOut = mockERC20;
        amountIn = bound(amountIn, 1e1, 1e12);
        deal(address(tokenIn), user, amountIn);

        // Create signed permit
        uint256 nonce = 0;
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(tokenIn);
        amounts[0] = amountIn;
        ISignatureTransfer.PermitBatchTransferFrom memory permit = defaultERC20PermitMultiple(tokens, amounts, nonce);
        bytes memory sig = getPermitBatchTransferSignature(permit, address(spender), userPrivateKey, DOMAIN_SEPARATOR);

        // Create transfer details
        ISignatureTransfer.SignatureTransferDetails[] memory transferDetails = new ISignatureTransfer.SignatureTransferDetails[](1);
        transferDetails[0] = ISignatureTransfer.SignatureTransferDetails({to: address(router), requestedAmount: amountIn});

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitPullTokens(permit, transferDetails, sig);

        // Encode execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertGt(tokenOut.balanceOf(address(user)), 0);
    }

    function testPermitPullTokensLengthMismatch() external {
        IERC20 tokenIn = mockERC20;
        IERC20 tokenOut = mockERC20;
        deal(address(tokenIn), user, defaultSignatureAmount);

        // Create signed permit
        uint256 nonce = 0;
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(tokenIn);
        tokens[1] = address(tokenIn);
        amounts[0] = defaultSignatureAmount;
        amounts[1] = defaultSignatureAmount;
        ISignatureTransfer.PermitBatchTransferFrom memory permit = defaultERC20PermitMultiple(tokens, amounts, nonce);
        bytes memory sig = getPermitBatchTransferSignature(permit, address(spender), userPrivateKey, DOMAIN_SEPARATOR);

        // Create transfer details
        ISignatureTransfer.SignatureTransferDetails[] memory transferDetails = new ISignatureTransfer.SignatureTransferDetails[](1);
        transferDetails[0] = ISignatureTransfer.SignatureTransferDetails({to: address(router), requestedAmount: defaultSignatureAmount});

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitPullTokens(permit, transferDetails, sig);

        // Encode execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.expectRevert(ISpenderPermit2ERC20.LengthMismatch.selector);
        router.execute(logics, tokensReturn);
    }

    function testSetAllowance() external {
        // Create signed permit
        IAllowanceTransfer.PermitSingle memory permit = defaultERC20PermitAllowance(address(mockERC20), defaultAllowanceAmount, address(spender), defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, userPrivateKey, DOMAIN_SEPARATOR);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitToken(permit, sig);

        // Encode execute
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);

        (uint160 amount, uint48 expiration, uint48 nonce) = IAllowanceTransfer(permit2Addr).allowance(address(user), address(mockERC20), address(spender));
        assertEq(amount, defaultAllowanceAmount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
    }

    function testSetAllowanceInvalidSpender() external {
        // Create signed permit
        IAllowanceTransfer.PermitSingle memory permit = defaultERC20PermitAllowance(address(mockERC20), defaultAllowanceAmount, address(this), defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, userPrivateKey, DOMAIN_SEPARATOR);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitToken(permit, sig);

        // Encode execute
        vm.expectRevert(ISpenderPermit2ERC20.InvalidSpender.selector);
        router.execute(logics, tokensReturnEmpty);
    }



    // Cannot call spender directly
    // function testCannotBeCalledByNonRouter(uint128 amount) external {
    //     vm.assume(amount > 0);
    //     deal(address(mockERC20), user, amount);

    //     vm.startPrank(user);
    //     vm.expectRevert(ISpenderPermit2ERC20.InvalidRouter.selector);
    //     spender.pullToken(address(mockERC20), amount);

    //     vm.expectRevert(ISpenderPermit2ERC20.InvalidRouter.selector);
    //     address[] memory tokens = new address[](1);
    //     uint256[] memory amounts = new uint256[](1);
    //     tokens[0] = address(mockERC20);
    //     amounts[0] = amount;
    //     spender.pullTokens(tokens, amounts);
    //     vm.stopPrank();
    // }

    function _logicSpenderPermit2ERC20PermitPullToken(ISignatureTransfer.PermitTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails memory transferDetails, bytes memory signature) public view returns (IRouter.Logic memory) {
        return
            IRouter.Logic(
                address(spender), // to
                abi.encodeWithSelector(spender.permitPullToken.selector, permit, transferDetails, signature),
                inputsEmpty,
                outputsEmpty,
                address(0) // callback
            );
    }

    function _logicSpenderPermit2ERC20PermitPullTokens(ISignatureTransfer.PermitBatchTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails[] memory transferDetails, bytes memory signature) public view returns (IRouter.Logic memory) {
        return
            IRouter.Logic(
                address(spender), // to
                abi.encodeWithSelector(spender.permitPullTokens.selector, permit, transferDetails, signature),
                inputsEmpty,
                outputsEmpty,
                address(0) // callback
            );
    }
    function _logicSpenderPermit2ERC20PermitToken(IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature) public view returns (IRouter.Logic memory) {
        return
            IRouter.Logic(
                address(spender), // to
                abi.encodeWithSelector(spender.permitToken.selector, permitSingle, signature),
                inputsEmpty,
                outputsEmpty,
                address(0) // callback
            );
    }
}
