// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract AlchemyGameUpgradeableV2 is Initializable, ERC1155Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    uint256 public totalNFT;
    uint256 public baseFee;
    address public fundAddress;
    bytes32 public merkleRoot;
    mapping(uint256 => Element) public elements;
    mapping(uint256 => mapping(uint256 => uint256)) public combinations;
    mapping(address => bool) public hasClaimedAirdrop;
    mapping(address => RoyaltyInfo) public creatorRoyalties;
    uint256 public nextElementId;
    uint256 public elementSubmissionFee;
    uint256 public royaltyPercentage;


    mapping(uint256 => Combination) public combinationList; 
    uint256 public combinationCount; 
    bool private combinationsMigrated; 

    struct Element {
        uint256 id;
        uint256 rarity;
        bool discovered;
        address creator;
        bool isUserCreated;
    }

    struct RoyaltyInfo {
        uint256 accumulatedRoyalties;
        bool isActive;
    }


    event ElementDiscovered(address indexed player, uint256 elementId);
    event NewElementCreated(address indexed creator, uint256 elementId, uint256 rarity);
    event NewCombinationAdded(address indexed creator, uint256 element1, uint256 element2, uint256 result);
    event RoyaltiesClaimed(address indexed creator, uint256 amount);

    struct Combination {
        uint256 element1;
        uint256 element2;
        uint256 result;
    }
    // Initialize function updated with new parameters
    function initializeV2(
        uint256 _elementSubmissionFee,
        uint256 _royaltyPercentage,
        uint256 _nextElementId
    ) public reinitializer(2) {
        require(_royaltyPercentage <= 50, "Royalty cannot exceed 50%");
        elementSubmissionFee = _elementSubmissionFee;
        royaltyPercentage = _royaltyPercentage;

        // Only set nextElementId if it hasn't been set yet (to avoid overwriting)
        if (nextElementId == 0) {
            nextElementId = _nextElementId; // Set to 47 during initialization
        }
        // Initialize new state variables
        combinationCount = 0;
        combinationsMigrated = false;
    }

    // Function to set the fund address
    function setFundAddress(address _account) external onlyOwner {
        fundAddress = _account;
    }

    // Function to set the base minting fee
    function setBaseFee(uint256 _baseFee) external onlyOwner {
        baseFee = _baseFee;
    }

    // Function to set the Merkle root for airdrop verification
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    // New function to set element submission fee
    function setElementSubmissionFee(uint256 _fee) external onlyOwner {
        elementSubmissionFee = _fee;
    }

    // New function to set royalty percentage
    function setRoyaltyPercentage(uint256 _percentage) external onlyOwner {
        require(_percentage <= 50, "Royalty cannot exceed 50%");
        royaltyPercentage = _percentage;
    }

    // Mint standard elements
    function mintStandardElements() external payable nonReentrant {
        require(balanceOf(msg.sender, 0) == 0, "Already owns Water");
        require(balanceOf(msg.sender, 1) == 0, "Already owns Air");
        require(balanceOf(msg.sender, 2) == 0, "Already owns Fire");
        require(balanceOf(msg.sender, 3) == 0, "Already owns Earth");
        require(msg.value >= baseFee * 4, "Insufficient ETH sent");

        (bool sent, ) = fundAddress.call{value: msg.value}("");
        require(sent, "Failed to send ETH");

        _mint(msg.sender, 0, 1, ""); // Water
        _mint(msg.sender, 1, 1, ""); // Air
        _mint(msg.sender, 2, 1, ""); // Fire
        _mint(msg.sender, 3, 1, ""); // Earth
        totalNFT += 4;
    }

    // Claim airdrop using Merkle proof
    function claimAirdrop(bytes32[] calldata _merkleProof) external nonReentrant {
        require(!hasClaimedAirdrop[msg.sender], "Airdrop already claimed");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "Invalid proof");

        hasClaimedAirdrop[msg.sender] = true;
        _mint(msg.sender, 0, 1, ""); // Water
        _mint(msg.sender, 1, 1, ""); // Air
        _mint(msg.sender, 2, 1, ""); // Fire
        _mint(msg.sender, 3, 1, ""); // Earth
        totalNFT += 4;
    }

    // New function for users to submit elements
    function submitElement(uint256 rarity) external payable nonReentrant {
        require(msg.value >= elementSubmissionFee, "Insufficient submission fee");
        require(rarity > 0 && rarity <= 10, "Invalid rarity range");

        uint256 newElementId = nextElementId++;
        
        elements[newElementId] = Element({
            id: newElementId,
            rarity: rarity,
            discovered: true, // User-created elements start as discovered
            creator: msg.sender,
            isUserCreated: true
        });

        // Initialize royalty tracking if first element
        if (!creatorRoyalties[msg.sender].isActive) {
            creatorRoyalties[msg.sender].isActive = true;
        }

        // Transfer submission fee to fund address
        (bool sent, ) = fundAddress.call{value: msg.value}("");
        require(sent, "Failed to send submission fee");

        emit NewElementCreated(msg.sender, newElementId, rarity);
    }

    // New function for users to submit combinations
    function submitCombination(uint256 element1, uint256 element2, uint256 result) external {
        require(elements[element1].discovered, "Element 1 not discovered");
        require(elements[element2].discovered, "Element 2 not discovered");
        require(elements[result].discovered, "Result element not discovered");
        require(combinations[element1][element2] == 0, "Combination already exists");
        
        // Only creator of the result element can add combinations using it
        require(
            elements[result].creator == msg.sender || 
            !elements[result].isUserCreated, 
            "Not authorized to use this result element"
        );

        _addCombination(element1, element2, result);
        emit NewCombinationAdded(msg.sender, element1, element2, result);
    }

    // Modified mint function to handle royalties
    function mint(uint256 element1, uint256 element2) external payable nonReentrant {
        require(balanceOf(msg.sender, element1) > 0, "Insufficient balance of element1");
        require(balanceOf(msg.sender, element2) > 0, "Insufficient balance of element2");

        uint256 newElement = combinations[element1][element2];
        require(newElement != 0, "Invalid combination");

        Element storage elem = elements[newElement];
        uint256 fee = calculateFee(elem.rarity);
        require(msg.value >= fee, "Insufficient ETH sent");

        // Handle royalty distribution if element was created by a user
        if (elem.isUserCreated && elem.creator != address(0)) {
            uint256 royaltyAmount = (fee * royaltyPercentage) / 100;
            uint256 fundAmount = fee - royaltyAmount;
            
            // Update creator's royalty balance
            creatorRoyalties[elem.creator].accumulatedRoyalties += royaltyAmount;
            
            // Transfer remaining amount to fund address
            (bool sent, ) = fundAddress.call{value: fundAmount}("");
            require(sent, "Failed to send ETH to fund");
        } else {
            // If not user-created, all fees go to fund address
            (bool sent, ) = fundAddress.call{value: fee}("");
            require(sent, "Failed to send ETH to fund");
        }

        _mint(msg.sender, newElement, 1, "");
        totalNFT++;

        if (!elem.discovered) {
            elem.discovered = true;
            emit ElementDiscovered(msg.sender, newElement);
        }
    }

    // New function for creators to claim their royalties
    function claimRoyalties() external nonReentrant {
        RoyaltyInfo storage royaltyInfo = creatorRoyalties[msg.sender];
        require(royaltyInfo.isActive, "No royalties to claim");
        require(royaltyInfo.accumulatedRoyalties > 0, "No royalties accumulated");

        uint256 amount = royaltyInfo.accumulatedRoyalties;
        royaltyInfo.accumulatedRoyalties = 0;

        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send royalties");

        emit RoyaltiesClaimed(msg.sender, amount);
    }

    // Function to calculate fee based on rarity
    function calculateFee(uint256 rarity) public view returns (uint256) {
        return baseFee * (rarity + 1);
    }

    // Migration function
    function migrateCombinations() external onlyOwner {
        require(!combinationsMigrated, "Combinations already migrated");

        // Loop through all possible pairs of elements
        for (uint256 i = 0; i < nextElementId; i++) {
            for (uint256 j = 0; j < nextElementId; j++) {
                uint256 result = combinations[i][j];
                if (result != 0) {
                    // Add the combination to the combinationList
                    combinationList[combinationCount] = Combination({
                        element1: i,
                        element2: j,
                        result: result
                    });
                    combinationCount++;
                }
            }
        }

        // Mark migration as complete
        combinationsMigrated = true;
    }
    // Initialize elements and combinations
    function _initializeElements() private {
        // Add basic elements
        _addElement(0, 1);
        _addElement(1, 1);
        _addElement(2, 1);
        _addElement(3, 1);

        // Add intermediate elements
        _addElement(4, 2);
        _addElement(5, 2);
        _addElement(6, 2);
        _addElement(7, 2);
        _addElement(8, 2);
        _addElement(9, 3);
        _addElement(10, 3);
        _addElement(11, 3);
        _addElement(12, 3);
        _addElement(13, 3);
        _addElement(14, 4);
        _addElement(15, 4);
        _addElement(16, 4);
        _addElement(17, 5);
        _addElement(18, 5);
        _addElement(19, 6);
        _addElement(20, 7);
        _addElement(21, 8);
        _addElement(22, 9);
        _addElement(23, 10);
        _addElement(24, 7);  // Smart Contract
        _addElement(25, 6);  // Token
        _addElement(26, 8);  // Dapp
        _addElement(27, 9);  // DAO
        _addElement(28, 8);  // Cryptocurrency
        _addElement(29, 7);  // Exchange
        _addElement(30, 8);  // Liquidity Pool
        _addElement(31, 9);  // Yield Farming
        _addElement(32, 6);  // Mining
        _addElement(33, 7);  // Proof of Work
        _addElement(34, 8);  // Consensus
        _addElement(35, 8);  // Governance Token
        _addElement(36, 9);  // DeFi
        _addElement(37, 10); // Decentralized Exchange
        _addElement(38, 7);  // Wallet
        _addElement(39, 8);  // Private Key
        _addElement(40, 7);  // Public Key
        _addElement(41, 8);  // Digital Signature
        _addElement(42, 9);  // Identity Verification
        _addElement(43, 4);  // Circuit
        _addElement(44, 6);  // Network
        _addElement(45, 7);  // Node
        _addElement(46, 8);  // Validator

        // Add combinations
        _addCombination(0, 1, 7);  // Water + Air = Rain
        _addCombination(0, 2, 4);  // Water + Fire = Steam
        _addCombination(0, 3, 8);  // Water + Earth = Mud
        _addCombination(1, 2, 5);  // Air + Fire = Energy
        _addCombination(1, 10, 11);  // Air + Rock = Sand
        _addCombination(2, 3, 6);  // Fire + Earth = Lava
        _addCombination(2, 10, 12);  // Fire + Rock = Metal
        _addCombination(2, 11, 13);  // Fire + Sand = Glass
        _addCombination(3, 7, 9);  // Earth + Rain = Plant
        _addCombination(6, 1, 10);  // Lava + Air = Rock
        _addCombination(8, 9, 14);  // Mud + Plant = Swamp
        _addCombination(13, 13, 15);  // Glass + Glass = Eyeglasses
        _addCombination(5, 12, 16);  // Energy + Metal = Electricity
        _addCombination(5, 8, 17);  // Energy + Mud = Life
        _addCombination(17, 3, 18);  // Life + Earth = Human
        _addCombination(15, 18, 19);  // Eyeglasses + Human = Nerd
        _addCombination(16, 19, 20);  // Electricity + Nerd = Computer
        _addCombination(20, 20, 21);  // Computer + Computer = Internet
        _addCombination(20, 21, 22);  // Computer + Internet = Blockchain
        _addCombination(22, 19, 23);  // Blockchain + Nerd = Bitcoin
        _addCombination(22, 17, 24);  // Blockchain + Life = Smart Contract
        _addCombination(24, 12, 25);  // Smart Contract + Metal = Token
        _addCombination(24, 5, 26);   // Smart Contract + Energy = Dapp
        _addCombination(26, 9, 27);   // Dapp + Plant = DAO
        _addCombination(23, 24, 28);  // Bitcoin + Smart Contract = Cryptocurrency
        _addCombination(28, 11, 29);  // Cryptocurrency + Sand = Exchange
        _addCombination(29, 25, 30);  // Exchange + Token = Liquidity Pool
        _addCombination(30, 16, 31);  // Liquidity Pool + Electricity = Yield Farming
        _addCombination(23, 5, 32);   // Bitcoin + Energy = Mining
        _addCombination(32, 6, 33);   // Mining + Lava = Proof of Work
        _addCombination(33, 17, 34);  // Proof of Work + Life = Consensus
        _addCombination(34, 25, 35);  // Consensus + Token = Governance Token
        _addCombination(35, 26, 36);  // Governance Token + Dapp = DeFi
        _addCombination(36, 14, 37);  // DeFi + Swamp = Decentralized Exchange
        _addCombination(28, 22, 38);  // Cryptocurrency + Blockchain = Wallet
        _addCombination(38, 16, 39);  // Wallet + Electricity = Private Key
        _addCombination(39, 19, 40);  // Private Key + Nerd = Public Key
        _addCombination(40, 10, 41);  // Public Key + Rock = Digital Signature
        _addCombination(41, 24, 42);  // Digital Signature + Smart Contract = Identity Verification
    }

    // Owner can add a new element
    function addElement(uint256 id, uint256 rarity) public onlyOwner {
        _addElement(id, rarity);
    }

    // Owner can add a new combination
    function addCombination(uint256 element1, uint256 element2, uint256 result) public onlyOwner {
        require(combinations[element1][element2] == 0, "Combination already exists");
        _addCombination(element1, element2, result);
    }

    // Internal function to add elements
    function _addElement(uint256 id, uint256 rarity) private {
        elements[id] = Element({
            id: id,
            rarity: rarity,
            discovered: false,
            creator: address(0),
            isUserCreated: false
        });
    }

    // Internal function to add combinations
    function _addCombination(uint256 element1, uint256 element2, uint256 result) private {
        combinations[element1][element2] = result;
        combinations[element2][element1] = result;

        // Add the combination to the combinationList
        combinationList[combinationCount] = Combination({
            element1: element1,
            element2: element2,
            result: result
        });
        combinationCount++;
    }

    // Returns total supply of NFTs
    function totalSupply() public view returns (uint256) {
        return totalNFT;
    }

    // Returns details of an element
    function elementDetails(uint256 id) public view returns (uint256, uint256, bool, address, bool) {
        Element memory elem = elements[id];
        return (elem.id, elem.rarity, elem.discovered, elem.creator, elem.isUserCreated);
    }

    // URI for element metadata
    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(tokenId), Strings.toString(tokenId), ".json"));
    }

    // New view function to get creator's royalty info
    function getCreatorRoyalties(address creator) external view returns (uint256, bool) {
        RoyaltyInfo memory royaltyInfo = creatorRoyalties[creator];
        return (royaltyInfo.accumulatedRoyalties, royaltyInfo.isActive);
    }

    // Function to get all elements created by a specific creator
    function getCreatorElements(address creator) external view returns (uint256[] memory) {
        uint256 count = 0;
        
        // First count elements by this creator
        for (uint256 i = 0; i < nextElementId; i++) {
            if (elements[i].creator == creator) {
                count++;
            }
        }

        // Create and fill array
        uint256[] memory creatorElements = new uint256[](count);
        uint256 index = 0;
        
        for (uint256 i = 0; i < nextElementId; i++) {
            if (elements[i].creator == creator) {
                creatorElements[index] = i;
                index++;
            }
        }

        return creatorElements;
    }

    function getAllCombinations() external view returns (Combination[] memory) {
        Combination[] memory allCombinations = new Combination[](combinationCount);
        for (uint256 i = 0; i < combinationCount; i++) {
            allCombinations[i] = combinationList[i];
        }
        return allCombinations;
    }

    function hasCombination(uint256 element1, uint256 element2) external view returns (bool) {
        return combinations[element1][element2] != 0;
    }
}