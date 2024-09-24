// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract AlchemyGameUpgradeable is Initializable, ERC1155Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    uint256 public totalNFT;
    uint256 public baseFee;
    address public fundAddress;
    bytes32 public merkleRoot;

    struct Element {
        uint256 id;
        uint256 rarity;
        bool discovered;
    }

    mapping(uint256 => Element) public elements;
    mapping(uint256 => mapping(uint256 => uint256)) public combinations;
    mapping(address => bool) public hasClaimedAirdrop;

    event ElementDiscovered(address indexed player, uint256 elementId);

    // Replace constructor with initializer function for upgradeable contracts
    function initialize(string memory _uri) public initializer {
        __ERC1155_init(_uri);
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        baseFee = 0.00001 ether;
        _initializeElements();
        fundAddress = msg.sender;
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

    // Mint new element by combining two existing ones
    function mint(uint256 element1, uint256 element2) external payable nonReentrant {
        require(balanceOf(msg.sender, element1) > 0, "Insufficient balance of element1");
        require(balanceOf(msg.sender, element2) > 0, "Insufficient balance of element2");

        uint256 newElement = combinations[element1][element2];
        require(newElement != 0, "Invalid combination");

        Element storage elem = elements[newElement];
        uint256 fee = calculateFee(elem.rarity);
        require(msg.value >= fee, "Insufficient ETH sent");

        (bool sent, ) = fundAddress.call{value: msg.value}("");
        require(sent, "Failed to send ETH");

        _mint(msg.sender, newElement, 1, "");
        totalNFT++;

        if (!elem.discovered) {
            elem.discovered = true;
            emit ElementDiscovered(msg.sender, newElement);
        }
    }

    // Function to calculate fee based on rarity
    function calculateFee(uint256 rarity) public view returns (uint256) {
        return baseFee * (rarity + 1);
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
        elements[id] = Element(id, rarity, false);
    }

    // Internal function to add combinations
    function _addCombination(uint256 element1, uint256 element2, uint256 result) private {
        combinations[element1][element2] = result;
        combinations[element2][element1] = result;
    }

    // Returns total supply of NFTs
    function totalSupply() public view returns (uint256) {
        return totalNFT;
    }

    // Returns details of an element
    function elementDetails(uint256 id) public view returns (uint256, uint256, bool) {
        Element memory elem = elements[id];
        return (elem.id, elem.rarity, elem.discovered);
    }

    // URI for element metadata
    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(tokenId), Strings.toString(tokenId), ".json"));
    }
}
