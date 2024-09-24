// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IAlchemyGame is IERC1155 {
    function elementDetails(uint256 id) external view returns (uint256, uint256, bool);
}

contract OpenALCHIMarketplaceUpgradeable is Initializable, ERC1155HolderUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    IAlchemyGame public alchemyGame;

    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        uint256 swapTokenId; // 0 if listed for price, otherwise the desired swap token
        uint256 createdAt;   // Timestamp to mitigate front-running
    }

    mapping(uint256 => Listing) public listings;
    uint256 public listingCounter;

    uint256 public feePercentage;
    uint256 public constant FEE_DENOMINATOR = 10000;
    address public fundAddress;
    uint256 public collectedFees;

    event ItemListed(uint256 listingId, address seller, uint256 tokenId, uint256 amount, uint256 price, uint256 swapTokenId);
    event ItemSold(uint256 listingId, address buyer, uint256 tokenId, uint256 amount, uint256 price);
    event ItemSwapped(uint256 listingId, address buyer, uint256 boughtTokenId, uint256 soldTokenId, uint256 amount);
    event ItemCanceled(uint256 listingId);
    event FundAddressUpdated(address newFundAddress);
    event FeesWithdrawn(address to, uint256 amount);

    // Replace constructor with initializer function
    function initialize(address _alchemyGame, uint256 _feePercentage, address _fundAddress) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        alchemyGame = IAlchemyGame(_alchemyGame);
        feePercentage = _feePercentage;
        fundAddress = _fundAddress;
    }

    function listItem(uint256 tokenId, uint256 amount, uint256 price, uint256 swapTokenId) external {
        require(amount > 0, "Amount must be greater than 0");
        require(price > 0 || swapTokenId != 0, "Must set a price or a swap token");
        require(price == 0 || swapTokenId == 0, "Cannot set both price and swap token");

        if (swapTokenId != 0) {
            (,uint256 listedRarity,) = alchemyGame.elementDetails(tokenId);
            (,uint256 swapRarity,) = alchemyGame.elementDetails(swapTokenId);
            require(listedRarity == swapRarity, "Swap token must have the same rarity");
        }

        alchemyGame.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

        listingCounter++;
        listings[listingCounter] = Listing({
            seller: msg.sender,
            tokenId: tokenId,
            amount: amount,
            price: price,
            swapTokenId: swapTokenId,
            createdAt: block.timestamp
        });

        emit ItemListed(listingCounter, msg.sender, tokenId, amount, price, swapTokenId);
    }

    function buyItem(uint256 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.seller != address(0), "Listing does not exist");
        require(listing.price > 0, "Item not listed for sale");
        require(block.timestamp >= listing.createdAt + 1 minutes, "Listing is too recent");
        require(msg.value >= listing.price, "Insufficient payment");

        uint256 feeAmount = (listing.price * feePercentage) / FEE_DENOMINATOR;
        uint256 sellerAmount = listing.price - feeAmount;

        payable(listing.seller).transfer(sellerAmount);
        collectedFees += feeAmount;

        alchemyGame.safeTransferFrom(address(this), msg.sender, listing.tokenId, listing.amount, "");

        emit ItemSold(listingId, msg.sender, listing.tokenId, listing.amount, listing.price);

        delete listings[listingId];
    }

    function swapItem(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.seller != address(0), "Listing does not exist");
        require(listing.swapTokenId != 0, "Item not listed for swap");

        uint256 swapperBalance = alchemyGame.balanceOf(msg.sender, listing.swapTokenId);
        require(swapperBalance >= listing.amount, "Insufficient balance of swap token");

        alchemyGame.safeTransferFrom(msg.sender, listing.seller, listing.swapTokenId, listing.amount, "");
        alchemyGame.safeTransferFrom(address(this), msg.sender, listing.tokenId, listing.amount, "");

        emit ItemSwapped(listingId, msg.sender, listing.tokenId, listing.swapTokenId, listing.amount);

        delete listings[listingId];
    }

    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.seller == msg.sender, "Not the seller");

        alchemyGame.safeTransferFrom(address(this), msg.sender, listing.tokenId, listing.amount, "");

        emit ItemCanceled(listingId);

        delete listings[listingId];
    }

    // View functions

    function getListingDetails(uint256 listingId) public view returns (Listing memory) {
        return listings[listingId];
    }

    function getAllListedTokens() public view returns (uint256[] memory, Listing[] memory) {
        uint256 activeListingsCount = 0;

        for (uint256 i = 1; i <= listingCounter; i++) {
            if (listings[i].seller != address(0)) {
                activeListingsCount++;
            }
        }

        uint256[] memory listingIds = new uint256[](activeListingsCount);
        Listing[] memory activeListings = new Listing[](activeListingsCount);

        uint256 currentIndex = 0;

        for (uint256 i = 1; i <= listingCounter; i++) {
            if (listings[i].seller != address(0)) {
                listingIds[currentIndex] = i;
                activeListings[currentIndex] = listings[i];
                currentIndex++;
            }
        }

        return (listingIds, activeListings);
    }

    function getElementRarity(uint256 tokenId) public view returns (uint256) {
        (,uint256 rarity,) = alchemyGame.elementDetails(tokenId);
        return rarity;
    }

    function setFundAddress(address _fundAddress) external onlyOwner {
        require(_fundAddress != address(0), "Invalid fund address");
        fundAddress = _fundAddress;
        emit FundAddressUpdated(_fundAddress);
    }

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage <= 1000, "Fee percentage cannot exceed 10%");
        feePercentage = _feePercentage;
    }

    function withdrawFees() external onlyOwner nonReentrant {
        require(fundAddress != address(0), "Fund address not set");
        uint256 amount = collectedFees;
        require(amount > 0, "No fees to withdraw");

        collectedFees = 0;
        (bool success, ) = fundAddress.call{value: amount}("");
        require(success, "Transfer failed");

        emit FeesWithdrawn(fundAddress, amount);
    }

    receive() external payable {}
}
