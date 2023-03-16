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
    MockERC721 public mockERC721A;
    MockERC721 public mockERC721B;
    IParam.Input[] inputsEmpty;

    function setUp() external {
        user = makeAddr('User');
        // Setup router and agent mock
        router = makeAddr('Router');
        vm.etch(router, 'code');
        agent = makeAddr('Agent');
        vm.etch(agent, 'code');

        spender = new SpenderERC721Approval(router);
        mockERC721A = new MockERC721('Mock ERC721A', 'mERC721A');
        mockERC721B = new MockERC721('Mock ERC721B', 'mERC721B');

        // User approved spender
        vm.startPrank(user);
        mockERC721A.setApprovalForAll(address(spender), true);
        mockERC721B.setApprovalForAll(address(spender), true);
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
        vm.label(address(mockERC721A), 'mERC721A');
        vm.label(address(mockERC721B), 'mERC721B');
    }

    function testPullToken(uint256 tokenId) external {
        MockERC721 nft = mockERC721A;
        tokenId = bound(tokenId, 0, 1e12);
        nft.mint(user, tokenId);

        vm.prank(agent);
        spender.pullToken(address(nft), tokenId);

        assertEq(nft.balanceOf(address(spender)), 0);
        assertEq(nft.balanceOf(address(router)), 0);
        assertEq(nft.ownerOf(tokenId), address(agent));
    }

    function testPullTokens(uint256 tokenId) external {
        MockERC721 nftA = mockERC721A;
        MockERC721 nftB = mockERC721B;
        tokenId = bound(tokenId, 0, 1e12);
        nftA.mint(user, tokenId);
        nftB.mint(user, tokenId);

        address[] memory tokens = new address[](2);
        uint256[] memory tokenIds = new uint256[](2);
        tokens[0] = address(mockERC721A);
        tokenIds[0] = tokenId;
        tokens[1] = address(mockERC721B);
        tokenIds[1] = tokenId;

        vm.prank(agent);
        spender.pullTokens(tokens, tokenIds);

        assertEq(nftA.balanceOf(address(spender)), 0);
        assertEq(nftA.balanceOf(address(router)), 0);
        assertEq(nftA.ownerOf(tokenId), address(agent));

        assertEq(nftB.balanceOf(address(spender)), 0);
        assertEq(nftB.balanceOf(address(router)), 0);
        assertEq(nftB.ownerOf(tokenId), address(agent));
    }

    // Cannot call spender directly
    function testCannotPullTokenByNonAgent(uint256 tokenId) external {
        MockERC721 nft = mockERC721A;
        nft.mint(user, tokenId);

        vm.startPrank(user);
        vm.expectRevert(ISpenderERC721Approval.InvalidAgent.selector);
        spender.pullToken(address(mockERC721A), tokenId);
        vm.stopPrank();
    }

    function testCannotPullTokensByNonAgent(uint256 tokenId) external {
        MockERC721 nft = mockERC721A;
        nft.mint(user, tokenId);

        vm.startPrank(user);
        vm.expectRevert(ISpenderERC721Approval.InvalidAgent.selector);
        address[] memory tokens = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        tokens[0] = address(mockERC721A);
        tokenIds[0] = tokenId;
        spender.pullTokens(tokens, tokenIds);
        vm.stopPrank();
    }
}
