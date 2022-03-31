// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IShillaBadge {
    function highestBadgeLevel() external returns (uint8 id);
    function canMintTo(
        address minter,
        uint8 badgeLevel, 
        address to, 
        uint256 balanceOfTo, 
        bool getBalance
    ) external returns (bool);
    function mint(uint8 badgeLevel, address to) external returns (uint256 id);
}