// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ERC721, IERC721} from 'openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import {IAgent} from '../src/interfaces/IAgent.sol';
import {IParam} from '../src/interfaces/IParam.sol';
import {SpenderERC721Approval, ISpenderERC721Approval} from '../src/SpenderERC721Approval.sol';
import {MockERC721} from './mocks/MockERC721.sol';

contract SpenderERC721ApprovalTest is Test {
    address public user;
    address public router;
    address public agent;
    ISpenderERC721Approval public spender;
    MockERC721 public mockERC721;
    IParam.Input[] inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        // Setup router and agent mock
        router = makeAddr('Router');
        vm.etch(router, 'code');
        agent = makeAddr('Agent');
        vm.etch(agent, 'code');

        spender = new SpenderERC721Approval(router);
        mockERC721 = new MockERC721('Mock ERC721', 'mERC721');

        // User approved spender
        vm.startPrank(user);
        mockERC721.setApprovalForAll(address(spender), true);
        vm.stopPrank();

        // Return activated agent from router
        vm.mockCall(router, 0, abi.encodeWithSignature('user()'), abi.encode(user));
        vm.mockCall(router, 0, abi.encodeWithSignature('getAgent()'), abi.encode(agent));
        vm.mockCall(router, 0, abi.encodeWithSignature('getUserAgent()'), abi.encode(user, agent));
        vm.mockCall(
            agent,
            0,
            abi.encodeWithSignature('onERC721Received(address,address,uint256,bytes)'),
            abi.encode(bytes4(abi.encodeWithSignature('onERC721Received(address,address,uint256,bytes)'))) // onERC721Received.selector
        );
        vm.label(address(spender), 'SpenderERC721Approval');
        vm.label(address(mockERC721), 'mERC721');
    }

    function testPullToken(uint256 tokenId) external {
        MockERC721 nft = mockERC721;
        tokenId = bound(tokenId, 0, 1e12);
        nft.mint(user, tokenId);

        vm.prank(agent);
        spender.pullToken(address(nft), tokenId);

        assertEq(nft.balanceOf(address(spender)), 0);
        assertEq(nft.balanceOf(address(router)), 0);
        assertEq(nft.ownerOf(tokenId), address(agent));
    }

    function testPullTokens(uint256 tokenId) external {
        MockERC721 nft = mockERC721;
        tokenId = bound(tokenId, 0, 1e12);
        nft.mint(user, tokenId);

        address[] memory tokens = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        tokens[0] = address(mockERC721);
        tokenIds[0] = tokenId;

        vm.prank(agent);
        spender.pullToken(address(nft), tokenId);

        assertEq(nft.balanceOf(address(spender)), 0);
        assertEq(nft.balanceOf(address(router)), 0);
        assertEq(nft.ownerOf(tokenId), address(agent));
    }

    // Cannot call spender directly
    function testCannotBeCalledByNonAgent(uint256 tokenId) external {
        MockERC721 nft = mockERC721;
        nft.mint(user, tokenId);

        vm.startPrank(user);
        vm.expectRevert(ISpenderERC721Approval.InvalidAgent.selector);
        spender.pullToken(address(mockERC721), tokenId);

        vm.expectRevert(ISpenderERC721Approval.InvalidAgent.selector);
        address[] memory tokens = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        tokens[0] = address(mockERC721);
        tokenIds[0] = tokenId;
        spender.pullTokens(tokens, tokenIds);
        vm.stopPrank();
    }
}
