// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract ERC721Metadata is ERC721Enumerable, Ownable {
    using Strings for uint256;

    // Base URI
    string private baseURI;
    string public baseExtension = ".json";

    bool public revealed = false;
    string public notRevealedUri;
    uint256 private _maxNftSupply;
    
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        string memory notRevealedUri_,
        uint256 maxNftSupply_
    ) ERC721(name_, symbol_) {
        setBaseURI(baseURI_);
        setNotRevealedURI(notRevealedUri_);
        _maxNftSupply = maxNftSupply_;
    }

    function setBaseURI(string memory baseURI_)
        private onlyOwner {
        require(
            keccak256(abi.encodePacked((baseURI))) !=
            keccak256(abi.encodePacked((baseURI_))),
            "ERC721Metadata: existed baseURI"
        );
        baseURI = baseURI_;
    }

    function reveal()
        external onlyOwner {
        revealed = true;
    }

    function setNotRevealedURI(string memory _notRevealedURI)
        private onlyOwner {
        notRevealedUri = _notRevealedURI;
    }

    function tokenURI(uint256 tokenId)
        public view override returns (string memory) {
        require(
            tokenId <= _maxNftSupply,
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (!_exists(tokenId) || !revealed) {
            return notRevealedUri;
        }

        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, tokenId.toString(), baseExtension))
            : "";
        }
}

contract Ractoons is ERC721Metadata {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    uint256 public constant MAX_NFT_SUPPLY = 10000;
    uint256 public constant MINT_PRICE = 2.5 ether;

    bool public paused = true;
    uint256 public pendingCount = MAX_NFT_SUPPLY;

    mapping(uint256 => address) public _minters;
    mapping(address => uint256) public _mintedByWallet;

    // Admin wallet
    address private _admin;

    uint256 private _totalDividend;
    uint256 private _reflectionBalance;
    mapping(uint256 => uint256) private _lastDividendAt;

    uint256 private _totalSupply;
    uint256 private _giveawayMax = 75;
    uint256[10001] private _pendingIDs;

    // Giveaway winners
    mapping(uint256 => address) private _giveaways;
    Counters.Counter private _giveawayCounter;

    event ClaimReward(uint256 indexed tokenID, uint256 balance);
    event ClaimRewards(address indexed owner, uint256 balance);

    constructor(
        string memory baseURI_,
        string memory notRevealedUri_,
        address admin_
    ) ERC721Metadata(
        "Ractoons",
        "RAC",
        baseURI_,
        notRevealedUri_,
        MAX_NFT_SUPPLY
    ) {
        _admin = admin_;
    }

    function totalSupply()
        public view override
        returns (uint256) {
        return _totalSupply;
    }

    /// @dev This function is for each address to claim their rewards 
    /// for all the token IDs of the given address.
    function claimRewards()
        external {
        uint count = balanceOf(_msgSender());
        uint256 balance = 0;
        for (uint i = 0; i < count; i++) {
            uint tokenId = tokenOfOwnerByIndex(_msgSender(), i);
            if (_giveaways[tokenId] != address(0)) continue;
            balance = balance.add(getReflectionBalance(tokenId));
            _lastDividendAt[tokenId] = _totalDividend;
        }
        payable(_msgSender()).transfer(balance);

        emit ClaimRewards(_msgSender(), balance);
    }

    /// @dev This function is for each token ID to claim their reward.
    /// @param tokenID_ This is the ID for which the reward is claimed.
    function claimReward(uint256 tokenID_)
        external {
        require(
            ownerOf(tokenID_) == _msgSender() ||
            getApproved(tokenID_) == _msgSender(),
            "Ractoons: Only owner or approved can claim rewards");

        require(
            _giveaways[tokenID_] == address(0),
            "Ractoons: Can't claim for giveaways");

        uint256 balance = getReflectionBalance(tokenID_);
        payable(ownerOf(tokenID_)).transfer(balance);
        _lastDividendAt[tokenID_] = _totalDividend;

        emit ClaimReward(tokenID_, balance);
    }

    /// @dev This function returns the balance by token ID.
    /// @param tokenID_ his is the ID for which the reflection balance is calculated.
    /// @return balance the reflected balance by token ID.
    function getReflectionBalance(uint256 tokenID_)
        public view returns (uint256 balance) {

        balance = _totalDividend
            .sub(_lastDividendAt[tokenID_]);
    }

    /// @dev This function returns the balance by address. It will return the 
    /// reflection balance for all of the token IDs that are minted by it.
    /// @param sender_ The address for which the reflected balance is calculated.
    /// @return the total reflected balance.
    function getReflectionBalances(address sender_)
        public view returns (uint256) {
        uint count = balanceOf(sender_);
        uint256 total = 0;

        for (uint i = 0; i < count; i++) {
            uint tokenID = tokenOfOwnerByIndex(sender_, i);
            if (_giveaways[tokenID] != address(0)) continue;
            total = total.add(getReflectionBalance(tokenID));
        }
        return total;
    }

    /// @dev This function collects all the token IDs of a wallet.
    /// @param owner_ This is the address for which the balance of token IDs is returned.
    /// @return an array of token IDs.
    function walletOfOwner(address owner_)
        external view returns (uint256[] memory) {
            uint256 ownerTokenCount = balanceOf(owner_);
            uint256[] memory tokenIDs = new uint256[](ownerTokenCount);
            for (uint256 i = 0; i < ownerTokenCount; i++) {
                tokenIDs[i] = tokenOfOwnerByIndex(owner_, i);
            }
            return tokenIDs;
    }

    function mint(uint256 counts_)
        external payable {
        require(pendingCount > 0, "Ractoons: All minted");
        require(counts_ > 0, "Ractoons: Counts cannot be zero");
        require(totalSupply().add(counts_) <= MAX_NFT_SUPPLY,
            "Ractoons: sale already ended");
        require(!paused, "Ractoons: The contract is paused");
        
        require(MINT_PRICE.mul(counts_) == msg.value,
            "Ractoons: invalid ether value");

        for (uint i = 0; i < counts_; i++) {
            _randomMint(_msgSender());
            _totalSupply += 1;
            _splitBalance(msg.value.div(counts_));
        }
    }
    
    function _randomMint(address to_)
        private returns (uint256) {

        require(to_ != address(0), "Ractoons: zero address");

        require(totalSupply() < MAX_NFT_SUPPLY,
            "Ractoons: max supply reached");

        uint256 randomIn = _getRandom()
            .mod(pendingCount)
            .add(1);

        uint256 tokenID = _popPendingAtIndex(randomIn);

        _minters[tokenID] = to_;
        _mintedByWallet[to_] += 1;

        _lastDividendAt[tokenID] = _totalDividend;
        _safeMint(to_, tokenID);

        return tokenID;
    }

    function _splitBalance(uint256 amount_)
        private {

        uint256 reflectionShare = amount_
            .mul(10)
            .div(100);

        uint256 subAmount = amount_
            .sub(reflectionShare);

        _reflectDividend(reflectionShare);
        payable(_admin).transfer(subAmount);
    }

    function _popPendingAtIndex(uint256 index_)
        private returns (uint256) {
        uint256 tokenID = _pendingIDs[index_].add(index_);

        if (index_ != pendingCount) {
            uint256 lastPendingID = _pendingIDs[pendingCount]
                .add(pendingCount);
            _pendingIDs[index_] = lastPendingID.sub(index_);
        }

        pendingCount -= 1;
        return tokenID;
    }

    function _getRandom()
        private view returns (uint256) {
        return uint256(keccak256(
            abi.encodePacked(block.difficulty, block.timestamp, pendingCount)
            )
        );
    }

    function _reflectDividend(uint256 amount_)
        private {
        _reflectionBalance = _reflectionBalance
            .add(amount_);
    
        uint256 fee = amount_
            .div(totalSupply());

        _totalDividend = _totalDividend
            .add(fee);
    }

    // onlyOwner

    function pause(bool state_)
        public onlyOwner {
        paused = state_;
    }

    function addToGiveawayMax(uint256 giveawayMax_)
        external onlyOwner {
        require(
            giveawayMax_ >= 0 && giveawayMax_ <= MAX_NFT_SUPPLY,
            "Ractoons: invalid max value"
        );

        _giveawayMax += giveawayMax_;
    }

    function randomGiveaway(address[] memory winners_)
        external onlyOwner {
        require(
            _giveawayCounter
                .current()
                .add(winners_.length) <= _giveawayMax,
            "Ractoons: overflow giveaways");

        for(uint i = 0; i < winners_.length; i++) {
            uint256 tokenID = _randomMint(winners_[i]);
            _giveaways[tokenID] = winners_[i];
            _giveawayCounter.increment();
        }

        _totalSupply = _totalSupply
            .add(winners_.length);
    }
}