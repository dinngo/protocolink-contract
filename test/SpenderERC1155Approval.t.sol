// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC1155, IERC1155} from 'openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol';
import {IAgent} from '../src/interfaces/IAgent.sol';
import {IParam} from '../src/interfaces/IParam.sol';
import {SpenderERC1155Approval, ISpenderERC1155Approval} from '../src/SpenderERC1155Approval.sol';
import {MockERC1155} from './mocks/MockERC1155.sol';

contract SpenderERC1155ApprovalTest is Test {
    address public user;
    address public router;
    address public agent;
    ISpenderERC1155Approval public spender;
    MockERC1155 public mockERC1155A;
    MockERC1155 public mockERC1155B;
    IParam.Input[] inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        // Setup router and agent mock
        router = makeAddr('Router');
        vm.etch(router, 'code');
        agent = makeAddr('Agent');
        vm.etch(agent, 'code');

        spender = new SpenderERC1155Approval(router);
        mockERC1155A = new MockERC1155('MockERC1155AURL');
        mockERC1155B = new MockERC1155('MockERC1155BURL');

        // User approved spender
        vm.startPrank(user);
        mockERC1155A.setApprovalForAll(address(spender), true);
        mockERC1155B.setApprovalForAll(address(spender), true);
        vm.stopPrank();

        // Return activated agent from router
        vm.mockCall(router, 0, abi.encodeWithSignature('user()'), abi.encode(user));
        vm.mockCall(router, 0, abi.encodeWithSignature('getAgent()'), abi.encode(agent));
        vm.mockCall(router, 0, abi.encodeWithSignature('getUserAgent()'), abi.encode(user, agent));
        vm.mockCall(
            agent,
            0,
            abi.encodeWithSignature('onERC1155Received(address,address,uint256,uint256,bytes)'),
            abi.encode(bytes4(abi.encodeWithSignature('onERC1155Received(address,address,uint256,uint256,bytes)'))) // onERC1155Received.selector
        );
        vm.mockCall(
            agent,
            0,
            abi.encodeWithSignature('onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)'),
            abi.encode(
                bytes4(abi.encodeWithSignature('onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)')) // onERC1155BatchReceived.selector
            ) // onERC1155Received.selector
        );

        vm.label(address(spender), 'SpenderERC1155Approval');
        vm.label(address(mockERC1155A), 'mERC1155A');
        vm.label(address(mockERC1155B), 'mERC1155B');
    }

    function testPullToken(uint256 tokenId, uint256 amount) external {
        MockERC1155 nft = mockERC1155A;
        tokenId = bound(tokenId, 0, 1e12);
        amount = bound(amount, 1, 1e12);
        nft.mint(user, tokenId, amount);

        // Prepare parameter for pullToken
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // Execute
        vm.prank(agent);
        spender.pullToken(address(nft), tokenIds, amounts);

        // Verify
        assertEq(nft.balanceOf(address(spender), tokenId), 0);
        assertEq(nft.balanceOf(address(router), tokenId), 0);
        assertEq(nft.balanceOf(address(agent), tokenId), amount);
    }

    function testPullTokens(uint256 tokenId, uint256 amount) external {
        MockERC1155 nftA = mockERC1155A;
        MockERC1155 nftB = mockERC1155B;
        tokenId = bound(tokenId, 0, 1e12);
        amount = bound(amount, 1, 1e12);
        amount = 0;
        nftA.mint(user, tokenId, amount);
        nftB.mint(user, tokenId, amount);

        // Prepare parameter for pullTokens
        address[] memory tokens = new address[](2);
        tokens[0] = address(nftA);
        tokens[1] = address(nftB);

        uint256[][] memory tokenIdsArray = new uint256[][](2);
        tokenIdsArray[0] = new uint256[](1);
        tokenIdsArray[1] = new uint256[](1);
        tokenIdsArray[0][0] = tokenId;
        tokenIdsArray[1][0] = tokenId;
        uint256[][] memory amountsArray = new uint256[][](2);
        amountsArray[0] = new uint256[](1);
        amountsArray[1] = new uint256[](1);
        amountsArray[0][0] = amount;
        amountsArray[1][0] = amount;

        // Execute
        vm.prank(agent);
        spender.pullTokens(tokens, tokenIdsArray, amountsArray);

        // Verify
        assertEq(nftA.balanceOf(address(spender), tokenId), 0);
        assertEq(nftA.balanceOf(address(router), tokenId), 0);
        assertEq(nftA.balanceOf(address(agent), tokenId), amount);

        assertEq(nftB.balanceOf(address(spender), tokenId), 0);
        assertEq(nftB.balanceOf(address(router), tokenId), 0);
        assertEq(nftB.balanceOf(address(agent), tokenId), amount);
    }

    // Cannot call spender directly
    function testCannotPullTokenByNonAgent(uint256 tokenId, uint256 amount) external {
        MockERC1155 nft = mockERC1155A;
        nft.mint(user, tokenId, amount);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        vm.startPrank(user);
        vm.expectRevert(ISpenderERC1155Approval.InvalidAgent.selector);
        spender.pullToken(address(nft), tokenIds, amounts);
        vm.stopPrank();
    }

    function testCannotPullTokensByNonAgent(uint256 tokenId, uint256 amount) external {
        MockERC1155 nft = mockERC1155A;
        nft.mint(user, tokenId, amount);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        address[] memory tokens = new address[](1);
        tokens[0] = address(nft);
        uint256[][] memory tokenIdsArray = new uint256[][](1);
        tokenIdsArray[0] = tokenIds;
        uint256[][] memory amountsArray = new uint256[][](1);

        amountsArray[0] = amounts;
        vm.startPrank(user);
        vm.expectRevert(ISpenderERC1155Approval.InvalidAgent.selector);
        spender.pullTokens(tokens, tokenIdsArray, amountsArray);
        vm.stopPrank();
    }
}
