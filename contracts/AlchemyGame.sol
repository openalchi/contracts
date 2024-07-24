// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract AlchemyGame is ERC1155, Ownable {
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

    constructor(string memory _uri) ERC1155(_uri) Ownable(msg.sender) {
        baseFee = 0.0005 ether;
        _initializeElements();
    }

    function setFundAddress(address _account) external onlyOwner {
        fundAddress = _account;
    }

    function setBaseFee(uint256 _baseFee) external onlyOwner {
        baseFee = _baseFee;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function mintStandardElements() external payable {
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

    function claimAirdrop(bytes32[] calldata _merkleProof) external {
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

    function mint(uint256 element1, uint256 element2) external payable {
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

    function calculateFee(uint256 rarity) public view returns (uint256) {
        return baseFee * (rarity + 1);
    }

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
    }

    function addElement(uint256 id, uint256 rarity) public onlyOwner {
        _addElement(id, rarity);
    }

    function addCombination(uint256 element1, uint256 element2, uint256 result) public onlyOwner {
        _addCombination(element1, element2, result);
    }

    function _addElement(uint256 id, uint256 rarity) private {
        elements[id] = Element(id, rarity, false);
    }

    function _addCombination(uint256 element1, uint256 element2, uint256 result) private {
        combinations[element1][element2] = result;
        combinations[element2][element1] = result;
    }

    function totalSupply() public view returns (uint256) {
        return totalNFT;
    }

    function elementDetails(uint256 id) public view returns (uint256, uint256, bool) {
        Element memory elem = elements[id];
        return (elem.id, elem.rarity, elem.discovered);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(tokenId), Strings.toString(tokenId), ".json"));
    }
}

