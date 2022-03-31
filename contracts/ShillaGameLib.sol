// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Base64.sol";
import "./HexStrings.sol";
import "./ShillaGame.sol";


library ShillaGameLib {
    using HexStrings for uint256;
    using HexStrings for address;

    string constant jsonDataUrl='data:application/json;base64,';
    string constant jsonDataId='{"name":"ShillaGame/';
    string constant jsonExtUrl='","description":"This NFT represents a Shilla Game, therefore every current owner of this NFT owns and profits from the game at ';
    string constant jsonDataImage='"},"image": "data:image/svg+xml;base64,';
    string constant jsonDataClose='"}';
    string constant svgBg1 = '<svg width="290" height="500" viewBox="0 0 290 500" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><defs><clipPath id="corners"><rect width="290" height="500" rx="42" ry="42"/></clipPath><linearGradient id="f1" gradientTransform="rotate(90)"><stop offset="0%" stop-color="#';
    string constant svgBg2 = '"/><stop offset="100%" stop-color="#';
    string constant svg1 = '"/></linearGradient><filter id="top-region-blur"><feGaussianBlur in="SourceGraphic" stdDeviation="24"/></filter></defs><g clip-path="url(#corners)"><rect fill="1f9840" x="0px" y="0px" width="290px" height="500px"/>';
    string constant svg2 = '<rect style="fill:url(#f1)" x="0px" y="0px" width="290px" height="500px"/><g style="filter:url(#top-region-blur);transform:scale(1.5);transform-origin:center top">';
    string constant svg3 = '<rect fill="none" x="0px" y="0px" width="290px" height="500px"/><ellipse cx="50%" cy="0px" rx="180px" ry="120px" fill="#000" opacity="0.85"/></g>';
    string constant ca = '<rect x="0" y="0" width="290" height="500" rx="42" ry="42" fill="rgba(0,0,0,0)" stroke="rgba(255,255,255,0.2)"/></g><text y="10px" x="32px" fill="white" font-family="Courier New, monospace" font-weight="200" font-size="9px">';
    string constant light = '</text><circle cx="32px" cy="32px" r="4px" fill="';
    string constant gameName = '" stroke="white"/><g><rect fill="none" x="0px" y="0px" width="290px" height="200px"/><text y="70px" x="32px" fill="white" font-family="Courier New, monospace" font-weight="200" font-size="34px">Shilla Game</text>';
    string constant gameIdT = '<text y="115px" x="32px" fill="white" font-family="Courier New, monospace" font-weight="200" font-size="30px">#';
    string constant hist1 = '</text></g><rect x="16" y="16" width="258" height="468" rx="26" ry="26" fill="rgba(0,0,0,0)" stroke="rgba(255,255,255,0.2)"/><g transform="translate(42, 325)"><text transform="rotate(270)" font-family="Courier New, monospace" font-size="12px" fill="white">Historical Game Average</text></g>';
    string constant hist2 = '<rect x="68" y="140" width="2" height="200" rx="26" ry="26" fill="#fff"/><rect x="50" y="130" width="35" height="220" rx="15" ry="15" fill="rgba(0,0,0,0.6)"/><circle cx="69px" cy="';
    string constant hist3 = '" r="4px" fill="white"/><circle cx="69px" cy="';
    string constant hist4 = '" r="8px" fill="none" stroke="white"/><g transform="translate(98, 300)"><text transform="rotate(270)" font-family="Courier New, monospace" font-size="14px" fill="white">';
    string constant late1 = '</text></g><g transform="translate(254, 315)"><text transform="rotate(270)" font-family="Courier New, monospace" font-size="12px" fill="white">Latest Game Session</text></g>';
    string constant late2 = '<rect x="222" y="140" width="2" height="200" rx="26" ry="26" fill="#fff"/><rect x="205" y="130" width="35" height="220" rx="15" ry="15" fill="rgba(0,0,0,0.6)"/><circle cx="223px" cy="';
    string constant late3 = '" r="4px" fill="white"/><circle cx="223px" cy="';
    string constant late4 = '" r="8px" fill="none" stroke="white"/><g transform="translate(200, 300)"><text transform="rotate(270)" font-family="Courier New, monospace" font-size="14px" fill="white">';
    string constant pAndP = '</text></g><text x="50" y="365" font-family="Courier New, monospace" font-size="12px" fill="white">Popularity &amp; Profitability</text><g style="transform:translate(29px,384px)">';
    string constant entPriceW = '<rect width="';
    string constant entPrice = '" height="26px" rx="8px" ry="8px" fill="rgba(0,0,0,0.6)"/><text x="12px" y="17px" font-family="Courier New, monospace" font-size="12px" fill="white"><tspan fill="rgba(255,255,255,0.6)">Entry Price: </tspan>';
    string constant sessW = ' $SHILLA</text></g><g style="transform:translate(29px,414px)"><rect width="';
    string constant sess = '" height="26px" rx="8px" ry="8px" fill="rgba(0,0,0,0.6)"/><text x="12px" y="17px" font-family="Courier New, monospace" font-size="12px" fill="white"><tspan fill="rgba(255,255,255,0.6)">Total Sessions: </tspan>';
    string constant apsW = '</text></g><g style="transform:translate(29px,444px)"><rect width="';
    string constant aps = '" height="26px" rx="8px" ry="8px" fill="rgba(0,0,0,0.6)"/><text x="12px" y="17px" font-family="Courier New, monospace" font-size="12px" fill="white"><tspan fill="rgba(255,255,255,0.6)">Players/Session: </tspan>';
    string constant svgClose = '</text></g></svg>';
    
    function _bgW(uint8 charsLen) external pure returns(uint256) {
        return 8 * charsLen;
    }
    
    function _countDigits(uint256 number) external pure returns (uint8 digits) {
        if(number == 0) return 1;
        digits = 0;
        while (number != 0) {
            number /= 10;
            digits++;
        }
        return digits;
    }
    
    function _addressToString(address _address) external pure returns(string memory) {
        bytes memory data = abi.encodePacked(_address);
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
    
    function genSVG(ShillaGame.Game memory game, ShillaGame.GameData memory gameData) internal view returns (string memory) {

        string memory o;
        {
            o = string(abi.encodePacked(svgBg1,gameData.svgBg1));
            o = string(abi.encodePacked(o,svgBg2,gameData.svgBg2));
            o = string(abi.encodePacked(o,svg1,svg2,svg3));
        }
        {
            o = string(abi.encodePacked(o,ca,address(this).addressToString(),light,gameData.light));
            o = string(abi.encodePacked(o,gameName,gameIdT,game.id.toString()));
        }

        {
            o = string(abi.encodePacked(o,hist1,hist2,gameData.histY,hist3,gameData.histY));
            o = string(abi.encodePacked(o,hist4,gameData.hist));
        }
        {
            o = string(abi.encodePacked(o,late1,late2,gameData.lateY,late3,gameData.lateY));
            o = string(abi.encodePacked(o,late4,gameData.late));
        }

        {
            o = string(abi.encodePacked(o,pAndP,entPriceW,gameData.entPriceW));
            o = string(abi.encodePacked(o,entPrice,gameData.entPrice));
        }
        {
            o = string(abi.encodePacked(o,sessW,gameData.sessW,sess,gameData.sess));
            o = string(abi.encodePacked(o,apsW,gameData.apsW,aps,gameData.aps,svgClose));
        }

        return o;
    }

    function tokenURI(uint256 gameId, string memory baseURIextended, ShillaGame.Game memory game, ShillaGame.GameData memory gameData) external view returns (string memory) {
        return string(abi.encodePacked(jsonDataUrl,Base64.encode(bytes(string(abi.encodePacked(jsonDataId,gameId.toString(),jsonExtUrl,baseURIextended,gameId.toString(),jsonDataImage,Base64.encode(bytes(genSVG(game, gameData))),jsonDataClose))))));
    }
}