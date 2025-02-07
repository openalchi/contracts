// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AlchemyGameUpgradeableV2.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract AlchemyGameHelperV2 {
    AlchemyGameUpgradeableV2 public game;
    uint256 public constant BATCH_SIZE = 100;
    
    constructor(address _gameAddress) {
        game = AlchemyGameUpgradeableV2(_gameAddress);
    }

    struct ElementInfo {
        uint256 id;
        uint256 rarity;
        bool discovered;
        uint256 userBalance;
        address creator;      
        bool isUserCreated;   
        uint256 mintFee;      
    }

    struct CreatorInfo {
        address creator;
        uint256 accumulatedRoyalties;
        bool isActive;
        uint256[] createdElements;
    }

    struct CombinationInfo {
        uint256 element1;
        uint256 element2;
        uint256 result;
    }

    // Updated to include new element fields
    function getAllElements() external view returns (ElementInfo[] memory) {
        uint256 nextId = game.nextElementId();
        ElementInfo[] memory allElements = new ElementInfo[](nextId);
        
        for (uint256 i = 0; i < nextId; i++) {
            (uint256 id, uint256 rarity, bool discovered, address creator, bool isUserCreated) = game.elements(i);
            uint256 userBalance = game.balanceOf(msg.sender, i);
            uint256 mintFee = game.calculateFee(rarity);
            
            allElements[i] = ElementInfo(
                id,
                rarity,
                discovered,
                userBalance,
                creator,
                isUserCreated,
                mintFee
            );
        }
        return allElements;
    }

    // Updated to include new element fields
    function getUserElements(address user) external view returns (ElementInfo[] memory) {
        uint256 nextId = game.nextElementId();
        uint256[] memory balances = new uint256[](nextId);
        uint256 ownedCount = 0;

        // Get balances in batches to avoid gas limits
        for (uint256 i = 0; i < nextId; i += BATCH_SIZE) {
            uint256 endIndex = Math.min(i + BATCH_SIZE, nextId);
            address[] memory users = new address[](endIndex - i);
            uint256[] memory ids = new uint256[](endIndex - i);
            
            for (uint256 j = 0; j < endIndex - i; j++) {
                users[j] = user;
                ids[j] = i + j;
            }
            
            uint256[] memory batchBalances = game.balanceOfBatch(users, ids);
            for (uint256 j = 0; j < batchBalances.length; j++) {
                balances[i + j] = batchBalances[j];
                if (batchBalances[j] > 0) {
                    ownedCount++;
                }
            }
        }

        ElementInfo[] memory ownedElements = new ElementInfo[](ownedCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < nextId; i++) {
            if (balances[i] > 0) {
                (uint256 id, uint256 rarity, bool discovered, address creator, bool isUserCreated) = game.elements(i);
                uint256 mintFee = game.calculateFee(rarity);
                
                ownedElements[index] = ElementInfo(
                    id,
                    rarity,
                    discovered,
                    balances[i],
                    creator,
                    isUserCreated,
                    mintFee
                );
                index++;
            }
        }
        
        return ownedElements;
    }

    // Get all combinations
    function getAllCombinations() external view returns (CombinationInfo[] memory) {
        uint256 combinationCount = game.combinationCount();
        CombinationInfo[] memory allCombinations = new CombinationInfo[](combinationCount);

        for (uint256 i = 0; i < combinationCount; i++) {
            (uint256 element1, uint256 element2, uint256 result) = game.combinationList(i);
            allCombinations[i] = CombinationInfo({
                element1: element1,
                element2: element2,
                result: result
            });
        }

        return allCombinations;
    }

    // Check if a specific combination exists
    function hasCombination(uint256 element1, uint256 element2) external view returns (bool) {
        return game.combinations(element1, element2) != 0;
    }

    // Get possible combinations including user-created elements
    function getPossibleCombinations(uint256 elementId) external view returns (uint256[] memory) {
        uint256 nextId = game.nextElementId();
        uint256[] memory possibleCombinations = new uint256[](nextId);
        uint256 count = 0;

        for (uint256 i = 0; i < nextId; i++) {
            uint256 result = game.combinations(elementId, i);
            if (result != 0) {
                possibleCombinations[count] = result;
                count++;
            }
        }

        // Resize the array to remove empty slots
        assembly {
            mstore(possibleCombinations, count)
        }
        
        return possibleCombinations;
    }

    // Get creator information including their elements
    function getCreatorInfo(address creator) external view returns (CreatorInfo memory) {
        (uint256 royalties, bool isActive) = game.getCreatorRoyalties(creator);
        
        // Count creator's elements first
        uint256 nextId = game.nextElementId();
        uint256 elementCount = 0;
        
        for (uint256 i = 0; i < nextId; i++) {
            (,,,address elementCreator, bool isUserCreated) = game.elements(i);
            if (elementCreator == creator && isUserCreated) {
                elementCount++;
            }
        }
        
        // Create array of creator's elements
        uint256[] memory createdElements = new uint256[](elementCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < nextId; i++) {
            (,,,address elementCreator, bool isUserCreated) = game.elements(i);
            if (elementCreator == creator && isUserCreated) {
                createdElements[index] = i;
                index++;
            }
        }
        
        return CreatorInfo(
            creator,
            royalties,
            isActive,
            createdElements
        );
    }

    // Get all active creators
    function getAllCreators() external view returns (address[] memory) {
        uint256 nextId = game.nextElementId();
        address[] memory creators = new address[](nextId);
        uint256 count = 0;
        
        for (uint256 i = 0; i < nextId; i++) {
            (,,,address creator, bool isUserCreated) = game.elements(i);
            if (isUserCreated && creator != address(0)) {
                // Check if creator is already in the array
                bool exists = false;
                for (uint256 j = 0; j < count; j++) {
                    if (creators[j] == creator) {
                        exists = true;
                        break;
                    }
                }
                if (!exists) {
                    creators[count] = creator;
                    count++;
                }
            }
        }
        
        // Resize array to actual count
        assembly {
            mstore(creators, count)
        }
        
        return creators;
    }

    // Get game fees and settings
    function getGameSettings() external view returns (
        uint256 baseFee,
        uint256 elementSubmissionFee,
        uint256 royaltyPercentage
    ) {
        baseFee = game.baseFee();
        elementSubmissionFee = game.elementSubmissionFee();
        royaltyPercentage = game.royaltyPercentage();
    }

    // Existing helper functions
    function getElementFee(uint256 elementId) external view returns (uint256) {
        (,uint256 rarity,,,) = game.elements(elementId);
        return game.calculateFee(rarity);
    }

    function getTotalDiscoveredElements() external view returns (uint256) {
        uint256 nextId = game.nextElementId();
        uint256 discoveredCount = 0;
        
        for (uint256 i = 0; i < nextId; i++) {
            (,,bool discovered,,) = game.elements(i);
            if (discovered) {
                discoveredCount++;
            }
        }
        
        return discoveredCount;
    }

    // Get all elements created by users
    function getUserCreatedElements() external view returns (ElementInfo[] memory) {
        uint256 nextId = game.nextElementId();
        uint256 count = 0;
        
        // First count user-created elements
        for (uint256 i = 0; i < nextId; i++) {
            (,,,, bool isUserCreated) = game.elements(i);
            if (isUserCreated) {
                count++;
            }
        }
        
        ElementInfo[] memory userElements = new ElementInfo[](count);
        uint256 index = 0;
        
        // Fill array with user-created elements
        for (uint256 i = 0; i < nextId; i++) {
            (uint256 id, uint256 rarity, bool discovered, address creator, bool isUserCreated) = game.elements(i);
            if (isUserCreated) {
                uint256 userBalance = game.balanceOf(msg.sender, i);
                uint256 mintFee = game.calculateFee(rarity);
                
                userElements[index] = ElementInfo(
                    id,
                    rarity,
                    discovered,
                    userBalance,
                    creator,
                    isUserCreated,
                    mintFee
                );
                index++;
            }
        }
        
        return userElements;
    }
}