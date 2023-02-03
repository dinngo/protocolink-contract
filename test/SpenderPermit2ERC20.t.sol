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
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(address(tokenIn), amountIn, nonce);
        bytes memory sig = getPermitTransferSignature(permit, address(spender), userPrivateKey, DOMAIN_SEPARATOR);

        // Create transfer details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = _getTransferDetails(address(router), amountIn);

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
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(address(tokenIn), defaultSignatureAmount, nonce);
        bytes memory sig = getPermitTransferSignature(permit, address(spender), userPrivateKey, DOMAIN_SEPARATOR);

        // Create transfer details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = _getTransferDetails(address(router), defaultSignatureAmount);

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
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(address(tokenIn), defaultSignatureAmount, nonce);
        bytes memory sig = getPermitTransferSignature(permit, address(spender), userPrivateKey, DOMAIN_SEPARATOR);

        // Create transfer details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = _getTransferDetails(address(1), defaultSignatureAmount);

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
        transferDetails[0] = _getTransferDetails(address(router), amountIn);

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
        transferDetails[0] = _getTransferDetails(address(router), defaultSignatureAmount);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitPullTokens(permit, transferDetails, sig);

        // Encode execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.expectRevert(ISpenderPermit2ERC20.LengthMismatch.selector);
        router.execute(logics, tokensReturn);
    }

    function testPermitToken(uint160 amount) external {
        // Create signed permit
        IAllowanceTransfer.PermitSingle memory permit = defaultERC20PermitAllowance(address(mockERC20), amount, address(spender), defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, userPrivateKey, DOMAIN_SEPARATOR);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitToken(permit, sig);

        // Encode execute
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);

        (uint160 allowanceAmount, uint48 expiration, uint48 nonce) = IAllowanceTransfer(permit2Addr).allowance(address(user), address(mockERC20), address(spender));
        assertEq(allowanceAmount, amount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
    }

    function testPermitTokenInvalidSpender() external {
        // Create signed permit
        IAllowanceTransfer.PermitSingle memory permit = defaultERC20PermitAllowance(address(mockERC20), defaultAllowanceAmount, address(1), defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, userPrivateKey, DOMAIN_SEPARATOR);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitToken(permit, sig);

        // Encode execute
        vm.expectRevert(ISpenderPermit2ERC20.InvalidSpender.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testPermitTokens(uint160 amount) external {
        address[] memory tokens = new address[](1);
        uint160[] memory amounts = new uint160[](1);
        tokens[0] = address(mockERC20);
        amounts[0] = amount;

        // Create signed permit
        IAllowanceTransfer.PermitBatch memory permit = defaultERC20PermitBatchAllowance(tokens, amounts, address(spender), defaultExpiration, defaultNonce);
        bytes memory sig = getPermitBatchSignature(permit, userPrivateKey, DOMAIN_SEPARATOR);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitTokens(permit, sig);

        // Encode execute
        vm.prank(user);
        router.execute(logics, tokensReturnEmpty);

        (uint160 allowanceAmount, uint48 expiration, uint48 nonce) = IAllowanceTransfer(permit2Addr).allowance(address(user), address(mockERC20), address(spender));
        assertEq(allowanceAmount, amount);
        assertEq(expiration, defaultExpiration);
        assertEq(nonce, 1);
    }

    function testPermitTokensInvalidSpender() external {
        address[] memory tokens = new address[](1);
        uint160[] memory amounts = new uint160[](1);
        tokens[0] = address(mockERC20);
        amounts[0] = defaultAllowanceAmount;

        // Create signed permit
        IAllowanceTransfer.PermitBatch memory permit = defaultERC20PermitBatchAllowance(tokens, amounts, address(1), defaultExpiration, defaultNonce);
        bytes memory sig = getPermitBatchSignature(permit, userPrivateKey, DOMAIN_SEPARATOR);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PermitTokens(permit, sig);

        // Encode execute
        vm.expectRevert(ISpenderPermit2ERC20.InvalidSpender.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testPullToken(uint160 amountIn) external {
        IERC20 tokenIn = mockERC20;
        IERC20 tokenOut = mockERC20;
        amountIn = uint160(bound(uint256(amountIn), 1e1, 1e12));
        deal(address(tokenIn), user, amountIn);

        // Create signed permit
        IAllowanceTransfer.PermitSingle memory permit = defaultERC20PermitAllowance(address(tokenIn), type(uint160).max, address(spender), defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, userPrivateKey, DOMAIN_SEPARATOR);

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        logics[0] = _logicSpenderPermit2ERC20PermitToken(permit, sig);
        logics[1] = _logicSpenderPermit2ERC20PullToken(address(tokenIn), amountIn);

        // Encode execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertGt(tokenOut.balanceOf(user), 0);
    }

    function testPullTokens(uint160 amountIn) external {
        IERC20 tokenIn = mockERC20;
        IERC20 tokenOut = mockERC20;
        amountIn = uint160(bound(uint256(amountIn), 1e1, 1e12));
        deal(address(tokenIn), user, amountIn);

        // Create signed permit
        IAllowanceTransfer.PermitSingle memory permit = defaultERC20PermitAllowance(address(tokenIn), type(uint160).max, address(spender), defaultExpiration, defaultNonce);
        bytes memory sig = getPermitSignature(permit, userPrivateKey, DOMAIN_SEPARATOR);

        // Create allowance transfer details
        IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails = new IAllowanceTransfer.AllowanceTransferDetails[](1);
        transferDetails[0] = IAllowanceTransfer.AllowanceTransferDetails({from: address(user), to: address(router), amount: amountIn, token: address(tokenIn)});

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](2);
        logics[0] = _logicSpenderPermit2ERC20PermitToken(permit, sig);
        logics[1] = _logicSpenderPermit2ERC20PullTokens(transferDetails);

        // Encode execute
        address[] memory tokensReturn = new address[](1);
        tokensReturn[0] = address(tokenOut);
        vm.prank(user);
        router.execute(logics, tokensReturn);

        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenOut.balanceOf(address(router)), 0);
        assertGt(tokenOut.balanceOf(user), 0);
    }

    function testPullTokensInvalidTransferFrom() external {
        // Create allowance transfer details
        IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails = new IAllowanceTransfer.AllowanceTransferDetails[](1);
        transferDetails[0] = IAllowanceTransfer.AllowanceTransferDetails({from: address(1), to: address(router), amount: defaultAllowanceAmount, token: address(mockERC20)});

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PullTokens(transferDetails);

        // Encode execute
        vm.expectRevert(ISpenderPermit2ERC20.InvalidTransferFrom.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    function testPullTokensInvalidTransferTo() external {
        // Create allowance transfer details
        IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails = new IAllowanceTransfer.AllowanceTransferDetails[](1);
        transferDetails[0] = IAllowanceTransfer.AllowanceTransferDetails({from: address(this), to: address(1), amount: defaultAllowanceAmount, token: address(mockERC20)});

        // Encode logics
        IRouter.Logic[] memory logics = new IRouter.Logic[](1);
        logics[0] = _logicSpenderPermit2ERC20PullTokens(transferDetails);

        // Encode execute
        vm.expectRevert(ISpenderPermit2ERC20.InvalidTransferTo.selector);
        router.execute(logics, tokensReturnEmpty);
    }

    // Cannot call spender directly
    function testCannotBeCalledByNonRouter() external {
        vm.startPrank(user);
        {
            vm.expectRevert(ISpenderPermit2ERC20.InvalidRouter.selector);
            ISignatureTransfer.PermitTransferFrom memory permit;
            ISignatureTransfer.SignatureTransferDetails memory transferDetails;
            bytes memory signature;
            spender.permitPullToken(permit, transferDetails, signature);
        }
        {
            vm.expectRevert(ISpenderPermit2ERC20.InvalidRouter.selector);
            ISignatureTransfer.PermitBatchTransferFrom memory permit;
            ISignatureTransfer.SignatureTransferDetails[] memory transferDetails;
            bytes memory signature;
            spender.permitPullTokens(permit, transferDetails, signature);
        }
        {
            vm.expectRevert(ISpenderPermit2ERC20.InvalidRouter.selector);
            IAllowanceTransfer.PermitSingle memory permitSingle;
            bytes memory signature;
            spender.permitToken(permitSingle, signature);
        }
        {
            vm.expectRevert(ISpenderPermit2ERC20.InvalidRouter.selector);
            IAllowanceTransfer.PermitBatch memory permitBatch;
            bytes memory signature;
            spender.permitTokens(permitBatch, signature);
        }
        {
            vm.expectRevert(ISpenderPermit2ERC20.InvalidRouter.selector);
            spender.pullToken(address(mockERC20), 0);
        }
        {
            vm.expectRevert(ISpenderPermit2ERC20.InvalidRouter.selector);
            IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails;
            spender.pullTokens(transferDetails);
        }
        vm.stopPrank();
    }

    function _getTransferDetails(address to, uint256 amount) private pure returns (ISignatureTransfer.SignatureTransferDetails memory) {
        return ISignatureTransfer.SignatureTransferDetails({to: to, requestedAmount: amount});
    }

    function _logicSpenderPermit2ERC20PermitPullToken(ISignatureTransfer.PermitTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails memory transferDetails, bytes memory signature) public view returns (IRouter.Logic memory) {
        return _logicBuilder(abi.encodeWithSelector(spender.permitPullToken.selector, permit, transferDetails, signature));
    }

    function _logicSpenderPermit2ERC20PermitPullTokens(ISignatureTransfer.PermitBatchTransferFrom memory permit, ISignatureTransfer.SignatureTransferDetails[] memory transferDetails, bytes memory signature) public view returns (IRouter.Logic memory) {
        return _logicBuilder(abi.encodeWithSelector(spender.permitPullTokens.selector, permit, transferDetails, signature));
    }
    function _logicSpenderPermit2ERC20PermitToken(IAllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature) public view returns (IRouter.Logic memory) {
        return _logicBuilder(abi.encodeWithSelector(spender.permitToken.selector, permitSingle, signature));
    }

    function _logicSpenderPermit2ERC20PermitTokens(IAllowanceTransfer.PermitBatch memory permitBatch, bytes memory signature) public view returns (IRouter.Logic memory) {
        return _logicBuilder(abi.encodeWithSelector(spender.permitTokens.selector, permitBatch, signature));
    }

    function _logicSpenderPermit2ERC20PullToken(address token, uint160 amount) public view returns (IRouter.Logic memory) {
        return _logicBuilder(abi.encodeWithSelector(spender.pullToken.selector, token, amount));
    }

    function _logicSpenderPermit2ERC20PullTokens(IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails) public view returns (IRouter.Logic memory) {
        return _logicBuilder(abi.encodeWithSelector(spender.pullTokens.selector, transferDetails));
    }

    function _logicBuilder(bytes memory data) public view returns (IRouter.Logic memory) {
        return
            IRouter.Logic(
                address(spender), // to
                data,
                inputsEmpty,
                outputsEmpty,
                address(0) // callback
            );
    }
}
