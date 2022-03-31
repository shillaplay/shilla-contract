// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IShillaGame {
    function startSession(uint256 gameId, uint256 gameBankIncrement, uint256 startSecondsFromNow) external;
    function gamePlayInfo(uint256 gameId) external view returns(
        uint256 startBlock, 
        uint256 endBlock, 
        uint256 entryPrice,
        uint256 reserveBank,
        bool awaitingPlayers
    );
    function mint(
        uint256 entryPriceNoDecimals, 
        uint8 countDownDuration, 
        uint8 ownerPercentage, 
        uint8 primaryWinnerPercentage, 
        uint8 secondaryWinnerPercentage
    ) external returns (uint256 id);
    function updateGame(
        uint256 gameId, 
        uint256 entryPriceNoDecimals, 
        uint8 countDownDuration, 
        uint8 ownerPercentage, 
        uint8 primaryWinnerPercentage, 
        uint8 secondaryWinnerPercentage
    ) external;
    function fundGame(uint256 gameId, uint256 amount) external;
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function burn(uint256 gameId) external;
}