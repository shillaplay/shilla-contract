// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./HexStrings.sol";
import "./IShilla.sol";
using HexStrings for uint256;
using HexStrings for address;

contract ShillaBadge is ERC721, Ownable {
    using SafeERC20 for IShilla;
    using HexStrings for uint256;

    string public baseURIextended = "ipfs://QmZHgsPzcy4qYs4Rii3U9coocpAoPqTqVAb5ZYqbUnCkKX/";
    
    struct Badge {
        uint256 minShillaRequired;
        uint32 maxSupply;
        uint32 totalMinted;
    }

    IShilla public token;
    uint256 public lastBadgeId;
    uint8 public lastBadgeLevel;

    mapping(uint8 => Badge) badges;
    mapping(uint256 => uint8) public badgeLevelOf;
    mapping(address => uint256) public badgeOwnedBy;
    mapping(address => bool) public isDistributor;
    address[] public distributors;

    constructor(address _token) ERC721("Shilla Army Special Forces Badge", "ShillaBadge") {
        token = IShilla(_token);
        isDistributor[owner()] = true;
        distributors.push(owner());
    }
    
    function addBadgeLevel(uint32 maxSupply, uint256 minShillaRequired) external onlyOwner {
        lastBadgeLevel++;
        badges[lastBadgeLevel].maxSupply = maxSupply;
        badges[lastBadgeLevel].minShillaRequired = minShillaRequired;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 badgeId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, badgeId);
        require(badgeOwnedBy[to] == 0, "1 badge allowed");
        require(token.balanceOf(to) >= badges[badgeLevelOf[badgeId]].minShillaRequired, "Low tokens balance");
        badgeOwnedBy[from] = 0;
        badgeOwnedBy[to] = badgeId;
    }

    function mint(uint8 badgeLevel, address to) external returns (uint256 id) {
        require(isDistributor[msg.sender], "Access denied");
        require(to != address(0), "Invalid address");
        require(badgeLevel > 0 && badgeLevel <= lastBadgeLevel, "Invalid badge specified");
        require(badges[badgeLevel].maxSupply > badges[badgeLevel].totalMinted, "Max exceeded");
        
        badges[badgeLevel].totalMinted++;
        id = ++lastBadgeId;
        badgeLevelOf[id] = badgeLevel;
        _mint(to, id);
    }

    function _addDistributor(address account) external onlyOwner {
        require(!isDistributor[msg.sender], "Already added");
        require(distributors.length < 256, "distributor full");
        isDistributor[account] = true;
        distributors.push(account);
    }

    function _removeDistributor(address account) external onlyOwner {
        require(isDistributor[msg.sender], "Not added");
        for(uint8 i = 0; i < 256; i++) {
            if(distributors[i] == account) {
                distributors[i] = distributors[distributors.length - 1];
                distributors.pop();
                isDistributor[account] = false;
            }
        }
    }

    function _setBaseURI(string memory baseURI_) external onlyOwner() {
        baseURIextended = baseURI_;
    }

    function tokenURI(uint256 badgeId) override public view returns (string memory) {
        require(_exists(badgeId), "Invalid badge");
        return string(abi.encodePacked(baseURIextended,uint256(badgeLevelOf[badgeId]).toString()));
    }

    function canMintTo(
        address minter,
        uint8 badgeLevel, 
        address to, 
        uint256 balanceOfTo, 
        bool getBalance
    ) external view returns (bool) {
        if(getBalance) balanceOfTo = token.balanceOf(to);
        return ( 
            (minter == address(0) || isDistributor[minter]) && 
            to != address(0) && 
            badgeLevel > 0 && 
            badgeOwnedBy[to] == 0 && 
            badges[badgeLevel].maxSupply > badges[badgeLevel].totalMinted && 
            balanceOfTo >= badges[badgeLevel].minShillaRequired
        );
    }

    function badgeLevelInfo(uint8 levelId) external view returns (
        uint256 maxSupply,
        uint256 totalMinted, 
        uint256 minShillaRequired) {
        require(levelId <= lastBadgeLevel, "Invalid badge level");
        maxSupply = badges[levelId].maxSupply;
        totalMinted = badges[levelId].totalMinted;
        minShillaRequired = badges[levelId].minShillaRequired;
    }

    function getBadgeLevels() external view returns(
        uint8[] memory levels, 
        uint32[] memory maxSupply, 
        uint32[] memory totalMinted, 
        uint256[] memory minShillaRequired
    ) {
        uint8 j;
        levels = new uint8[](lastBadgeLevel);
        maxSupply = new uint32[](lastBadgeLevel);
        totalMinted = new uint32[](lastBadgeLevel);
        minShillaRequired = new uint256[](lastBadgeLevel);
        for(uint8 i = 1; i <= lastBadgeLevel; i++) {
            j = i - 1;
            levels[j] = i;
            maxSupply[j] = badges[i].maxSupply;
            totalMinted[j] = badges[i].totalMinted;
            minShillaRequired[j] = badges[i].minShillaRequired;
        }
    }
    
}