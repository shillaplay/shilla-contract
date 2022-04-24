
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721Leasable is ERC721 {

    // Mapping from token ID to leaser address
    mapping(uint256 => address) private _leasers;

    // Mapping from token ID to lease duration
    mapping(uint256 => uint256) private _leaseExpiries;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal override view returns (bool) {
        //No ownership actions such as transfer, burn, approve... can occur during lease
        if(_leasers[tokenId] != address(0)) {
            return _leasers[tokenId] == spender && _leaseExpiries[tokenId] <= block.timestamp;

        } else {
            require(_exists(tokenId), "ERC721Leasable: operator query for nonexistent token");
            address owner = ERC721.ownerOf(tokenId);
            return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
        }
        
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public virtual override view returns (address) {
        if(_leasers[tokenId] != address(0) && _leaseExpiries[tokenId] <= block.timestamp) {
            return _leasers[tokenId];
        }
        return super.ownerOf(tokenId);
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        require(_leasers[tokenId] == address(0), "ERC721Leasable: Can't approve a token on lease");
        super.approve(to, tokenId);
    }

    function leaseFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 duration
    ) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721Leasable: token on lease or transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
        _leasers[tokenId] = from;
        _leaseExpiries[tokenId] = duration;

    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        if(_leasers[tokenId] != address(0)) {
            _leasers[tokenId] = address(0);
        }
    }

    function isOnLease(uint256 tokenId) public virtual view returns (bool) {
        return _leasers[tokenId] != address(0);
    } 

}