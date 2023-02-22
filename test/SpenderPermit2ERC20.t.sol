// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {SafeERC20, IERC20, Address} from 'openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol';
import {ERC20} from 'openzeppelin-contracts/contracts/token/ERC20/ERC20.sol';
import {IAgent} from '../src/interfaces/IAgent.sol';
import {IParam} from '../src/interfaces/IParam.sol';
import {SpenderPermit2ERC20, ISpenderPermit2ERC20, ISignatureTransfer, IAllowanceTransfer} from '../src/SpenderPermit2ERC20.sol';
import {PermitSignature} from './utils/PermitSignature.sol';
import {EIP712} from 'permit2/EIP712.sol';
import {SignatureVerification} from 'permit2/libraries/SignatureVerification.sol';

contract SpenderPermit2ERC20Test is Test, PermitSignature {
    using SafeERC20 for IERC20;
    using Address for address;

    address public constant permit2Addr = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    uint256 public constant defaultSignatureAmount = 10 ** 18;
    uint160 public constant defaultAllowanceAmount = 10 ** 18;
    uint48 public constant defaultNonce = 0;
    uint48 public defaultExpiration = uint48(block.timestamp + 5);

    address public user;
    address public router;
    address public agent;
    uint256 public userPrivateKey;
    ISpenderPermit2ERC20 public spender;
    IERC20 public mockERC20;

    bytes32 DOMAIN_SEPARATOR;

    function setUp() external {
        (user, userPrivateKey) = makeAddrAndKey('User');
        // Setup router and agent mock
        router = makeAddr('Router');
        vm.etch(router, 'code');
        agent = makeAddr('Agent');
        vm.etch(agent, 'code');

        spender = new SpenderPermit2ERC20(router, permit2Addr);
        mockERC20 = new ERC20('Mock ERC20', 'mERC20');
        DOMAIN_SEPARATOR = EIP712(permit2Addr).DOMAIN_SEPARATOR();

        // User approved spender and permit2
        vm.startPrank(user);
        mockERC20.safeApprove(address(spender), type(uint256).max);
        mockERC20.safeApprove(permit2Addr, type(uint256).max);
        vm.stopPrank();

        // Return activated agent from router
        vm.mockCall(router, 0, abi.encodeWithSignature('user()'), abi.encode(user));
        vm.mockCall(router, 0, abi.encodeWithSignature('getAgent()'), abi.encode(agent));
        vm.mockCall(router, 0, abi.encodeWithSignature('getUserAgent()'), abi.encode(user, agent));
        vm.label(address(spender), 'SpenderPermit2ERC20');
        vm.label(address(mockERC20), 'mERC20');
        vm.label(permit2Addr, 'Permit2');
    }

    function testPermitPullToken(uint256 amountIn) external {
        IERC20 tokenIn = mockERC20;
        amountIn = bound(amountIn, 1e1, 1e12);
        deal(address(tokenIn), user, amountIn);

        // Create signed permit
        uint256 nonce = 0;
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(
            address(tokenIn),
            amountIn,
            nonce
        );
        bytes memory sig = getPermitTransferSignature(permit, address(spender), userPrivateKey, DOMAIN_SEPARATOR);

        // Create transfer details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = _getTransferDetails(agent, amountIn);

        // Execute
        vm.prank(agent);
        spender.permitPullToken(permit, transferDetails, sig);

        assertEq(tokenIn.balanceOf(address(spender)), 0);
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), amountIn);
    }

    function testPermitPullTokenInvalidUser() external {
        IERC20 tokenIn = mockERC20;
        (address other, uint256 otherPrivateKey) = makeAddrAndKey('Other');
        deal(address(tokenIn), other, defaultSignatureAmount);

        // Create signed permit
        uint256 nonce = 0;
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(
            address(tokenIn),
            defaultSignatureAmount,
            nonce
        );
        bytes memory sig = getPermitTransferSignature(permit, address(spender), otherPrivateKey, DOMAIN_SEPARATOR);

        // Create transfer details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = _getTransferDetails(
            agent,
            defaultSignatureAmount
        );

        // Execute
        vm.expectRevert(SignatureVerification.InvalidSigner.selector);
        vm.prank(agent);
        spender.permitPullToken(permit, transferDetails, sig);
    }

    function testPermitPullTokenInvalidTransferTo() external {
        IERC20 tokenIn = mockERC20;
        deal(address(tokenIn), user, defaultSignatureAmount);

        // Create signed permit
        uint256 nonce = 0;
        ISignatureTransfer.PermitTransferFrom memory permit = defaultERC20PermitTransfer(
            address(tokenIn),
            defaultSignatureAmount,
            nonce
        );
        bytes memory sig = getPermitTransferSignature(permit, address(spender), userPrivateKey, DOMAIN_SEPARATOR);

        // Create transfer details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = _getTransferDetails(
            address(1),
            defaultSignatureAmount
        );

        // Execute
        vm.expectRevert(ISpenderPermit2ERC20.InvalidTransferTo.selector);
        vm.prank(agent);
        spender.permitPullToken(permit, transferDetails, sig);
    }

    function testPermitPullTokens(uint256 amountIn) external {
        IERC20 tokenIn = mockERC20;
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
        ISignatureTransfer.SignatureTransferDetails[]
            memory transferDetails = new ISignatureTransfer.SignatureTransferDetails[](1);
        transferDetails[0] = _getTransferDetails(address(agent), amountIn);

        // Execute
        vm.prank(agent);
        spender.permitPullTokens(permit, transferDetails, sig);

        assertEq(tokenIn.balanceOf(address(spender)), 0);
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), amountIn);
    }

    function testPullToken(uint160 amountIn) external {
        IERC20 tokenIn = mockERC20;
        amountIn = uint160(bound(uint256(amountIn), 1e1, 1e12));
        deal(address(tokenIn), user, amountIn);

        // Create signed permit
        IAllowanceTransfer.PermitSingle memory permit = defaultERC20PermitAllowance(
            address(tokenIn),
            type(uint160).max,
            address(spender),
            defaultExpiration,
            defaultNonce
        );
        bytes memory sig = getPermitSignature(permit, userPrivateKey, DOMAIN_SEPARATOR);

        _permitToken(user, permit, sig);

        // Execute
        vm.prank(agent);
        spender.pullToken(address(tokenIn), amountIn);

        assertEq(tokenIn.balanceOf(address(spender)), 0);
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), amountIn);
    }

    function testPullTokens(uint160 amountIn) external {
        IERC20 tokenIn = mockERC20;
        amountIn = uint160(bound(uint256(amountIn), 1e1, 1e12));
        deal(address(tokenIn), user, amountIn);

        // Create signed permit
        IAllowanceTransfer.PermitSingle memory permit = defaultERC20PermitAllowance(
            address(tokenIn),
            type(uint160).max,
            address(spender),
            defaultExpiration,
            defaultNonce
        );
        bytes memory sig = getPermitSignature(permit, userPrivateKey, DOMAIN_SEPARATOR);

        _permitToken(user, permit, sig);

        // Create allowance transfer details
        IAllowanceTransfer.AllowanceTransferDetails[]
            memory transferDetails = new IAllowanceTransfer.AllowanceTransferDetails[](1);
        transferDetails[0] = IAllowanceTransfer.AllowanceTransferDetails({
            from: address(user),
            to: address(agent),
            amount: amountIn,
            token: address(tokenIn)
        });

        // Execute
        vm.prank(agent);
        spender.pullTokens(transferDetails);

        assertEq(tokenIn.balanceOf(address(spender)), 0);
        assertEq(tokenIn.balanceOf(address(router)), 0);
        assertEq(tokenIn.balanceOf(address(agent)), amountIn);
    }

    function testPullTokensInvalidTransferFrom() external {
        // Create allowance transfer details
        IAllowanceTransfer.AllowanceTransferDetails[]
            memory transferDetails = new IAllowanceTransfer.AllowanceTransferDetails[](1);
        transferDetails[0] = IAllowanceTransfer.AllowanceTransferDetails({
            from: address(1),
            to: address(agent),
            amount: defaultAllowanceAmount,
            token: address(mockERC20)
        });

        // Execute
        vm.expectRevert(ISpenderPermit2ERC20.InvalidTransferFrom.selector);
        vm.prank(agent);
        spender.pullTokens(transferDetails);
    }

    function testPullTokensInvalidTransferTo() external {
        IERC20 tokenIn = mockERC20;

        // Create signed permit
        IAllowanceTransfer.PermitSingle memory permit = defaultERC20PermitAllowance(
            address(tokenIn),
            type(uint160).max,
            address(spender),
            defaultExpiration,
            defaultNonce
        );
        bytes memory sig = getPermitSignature(permit, userPrivateKey, DOMAIN_SEPARATOR);

        _permitToken(user, permit, sig);

        // Create allowance transfer details
        IAllowanceTransfer.AllowanceTransferDetails[]
            memory transferDetails = new IAllowanceTransfer.AllowanceTransferDetails[](1);
        transferDetails[0] = IAllowanceTransfer.AllowanceTransferDetails({
            from: address(user),
            to: address(1),
            amount: defaultAllowanceAmount,
            token: address(tokenIn)
        });

        // Execute
        vm.expectRevert(ISpenderPermit2ERC20.InvalidTransferTo.selector);
        vm.prank(agent);
        spender.pullTokens(transferDetails);
    }

    // Cannot call spender directly
    function testCannotBeCalledByNonRouter() external {
        {
            vm.expectRevert(ISpenderPermit2ERC20.InvalidAgent.selector);
            ISignatureTransfer.PermitTransferFrom memory permit;
            ISignatureTransfer.SignatureTransferDetails memory transferDetails;
            bytes memory signature;
            spender.permitPullToken(permit, transferDetails, signature);
        }
        {
            vm.expectRevert(ISpenderPermit2ERC20.InvalidAgent.selector);
            ISignatureTransfer.PermitBatchTransferFrom memory permit;
            ISignatureTransfer.SignatureTransferDetails[] memory transferDetails;
            bytes memory signature;
            spender.permitPullTokens(permit, transferDetails, signature);
        }
        {
            vm.expectRevert(ISpenderPermit2ERC20.InvalidAgent.selector);
            spender.pullToken(address(mockERC20), 0);
        }
        {
            vm.expectRevert(ISpenderPermit2ERC20.InvalidAgent.selector);
            IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails;
            spender.pullTokens(transferDetails);
        }
    }

    function _getTransferDetails(
        address to,
        uint256 amount
    ) private pure returns (ISignatureTransfer.SignatureTransferDetails memory) {
        return ISignatureTransfer.SignatureTransferDetails({to: to, requestedAmount: amount});
    }

    function _permitToken(
        address owner,
        IAllowanceTransfer.PermitSingle memory permitSingle,
        bytes memory signature
    ) internal {
        /// The permit selector is not unique and must be specified using encodeWithSignature
        /// abi.encodeWithSelector(permit2.permit.selector, owner, permitSingle, signature)
        permit2Addr.functionCall(
            abi.encodeWithSignature(
                'permit(address,((address,uint160,uint48,uint48),address,uint256),bytes)',
                owner,
                permitSingle,
                signature
            )
        );
    }
}
