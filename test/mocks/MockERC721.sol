// SPDX-License-Identifier: MIT

import {ERC721} from 'openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';

pragma solidity ^0.8.0;

contract MockERC721 is ERC721 {
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }

    function isMinted(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }
}
