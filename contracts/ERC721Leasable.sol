
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721Leasable is ERC721 {
    // Mapping from account to a map of token ID to lease request duration
    mapping(address => mapping(uint256 => uint256)) private _durations;
    // Mapping owner address to token lease count count
    mapping(address => uint256) private _leaseOf;
    // Mapping from token ID to lease
    mapping(uint256 => Lease) private _leaseFor;

    struct Lease {
        address from;
        address to;
        uint256 expiry;
    }

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
    }

    modifier claimLease(address claimer, uint256 tokenId) {
        //If the token is a lease, both the leaser and the leasee must be sent to the block below
        //for scrutiny
        if(_leaseFor[tokenId].from != address(0)) {
            //Then the claimer has to be the leaser, and the lease expiry time must has elapsed.
            //This means since a leasee/claimer won't be the leaser/_leaseFor[tokenId].from,
            //The leasee can't transfer or approve a leased token.
            //Also, the leaser can't transfer or approve either until the lease has expired
            require(claimer == _leaseFor[tokenId].from && _leaseFor[tokenId].expiry <= block.timestamp, "1");
            _transfer(_leaseFor[tokenId].to, _leaseFor[tokenId].from, tokenId);
            _leaseFor[tokenId].from = address(0);
            _leaseFor[tokenId].to = address(0);
            _leaseFor[tokenId].expiry = 0;
            _leaseOf[claimer] = _leaseOf[claimer] - 1;
        }
        _;
    }

    modifier beforeLease(
        address from,
        address to,
        uint256 tokenId,
        uint256 duration
    ) {
        //To be more sure the receiver is aware of the lease, so to decrease the odds of malicous owners 
        // making ownership transfer deals while delivering lease instead.
        require(duration > 0 && _durations[to][tokenId] == duration, "2");
        //To avoid a user's ERC721Leasable.balanceOf increasing by 2 when a lease to same accounts occurs
        //This can be fixed by checking if the from and to are the same when updating the _leaseOf,
        //but there's no point in doing so. It will only cost normal users more gas fees.
        require(from != to, "3");

        _leaseFor[tokenId].from = from;
        _leaseFor[tokenId].to = to;
        _leaseFor[tokenId].expiry = block.timestamp + duration;
        _leaseOf[from] = _leaseOf[from] + 1;

        _durations[to][tokenId] = 0;
        _;
    }

    function requestLease(uint256 tokenId, uint256 duration) public virtual {
        require(_exists(tokenId), "2.1");
        _durations[_msgSender()][tokenId] = duration;
    }

    function leaseRequestOf(address account, uint256 tokenId) public virtual view returns(uint256) {
        require(_exists(tokenId), "2.2");
        return _durations[account][tokenId];
    }

    /**
     * @dev See {ERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override claimLease(_msgSender(), tokenId) {
        super.approve(to, tokenId);
    }

    /**
     * @dev See {ERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {ERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override claimLease(from, tokenId) {
        super.safeTransferFrom(from, to, tokenId, _data);
    }

    /**
     * @dev See {ERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override claimLease(from, tokenId) {
        super.transferFrom(from, to, tokenId);
    }

    function leaseFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 duration
    ) public virtual claimLease(from, tokenId) beforeLease(from, to, tokenId, duration) {
        super.transferFrom(from, to, tokenId);
    }

    function leaseInfo(uint256 tokenId) public virtual view returns (address from, address to, uint256 expiry) {
        from = _leaseFor[tokenId].from;
        to = _leaseFor[tokenId].to;
        expiry = _leaseFor[tokenId].expiry;
    }

    function leaseOf(address owner) public view virtual returns (uint256) {
        require(owner != address(0), "4");
        return _leaseOf[owner];
    }

    function ownerOf(uint256 tokenId) public virtual override view returns (address) {
        if(_leaseFor[tokenId].from != address(0) && _leaseFor[tokenId].expiry <= block.timestamp) {
            return _leaseFor[tokenId].from;
        }
        return ERC721.ownerOf(tokenId);
    }
    
    function balanceOf(address owner) public view virtual override returns (uint256 balance) {
        return ERC721.balanceOf(owner) + _leaseOf[owner];
    }

}