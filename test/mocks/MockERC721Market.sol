// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {ERC721Holder} from 'lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol';
import {MockERC721} from './MockERC721.sol';

contract MockERC721Market is ERC721Holder {
    uint256 public constant amount = 1000000;

    MockERC721 public nft;
    IERC20 public token;

    constructor(IERC20 token_) {
        token = token_;
        nft = new MockERC721('ERC721MarketNFT', 'EMN');
    }

    function nftToToken(uint256 tokenId) external {
        nft.safeTransferFrom(msg.sender, address(this), tokenId);
        token.transfer(msg.sender, amount);
    }

    function tokenToNft(uint256 tokenId, address recipient) external {
        token.transferFrom(msg.sender, address(this), amount);
        if (nft.isMinted(tokenId)) {
            nft.safeTransferFrom(address(this), recipient, tokenId);
        } else {
            nft.mint(recipient, tokenId);
        }
    }
}
