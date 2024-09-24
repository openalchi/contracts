// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AlchemyGame.sol";

contract AlchemyGameHelper {
    AlchemyGame public game;
    uint256 public constant MAX_ELEMENT_ID = 46;
    
    constructor(address _gameAddress) {
        game = AlchemyGame(_gameAddress);
    }

    struct ElementInfo {
        uint256 id;
        uint256 rarity;
        bool discovered;
        uint256 userBalance;
    }

    function getAllElements() external view returns (ElementInfo[] memory) {
        uint256 elementCount = game.totalNFT();
        ElementInfo[] memory allElements = new ElementInfo[](elementCount);

        for (uint256 i = 0; i < elementCount; i++) {
            (uint256 id, uint256 rarity, bool discovered) = game.elements(i);
            uint256 userBalance = game.balanceOf(msg.sender, i);
            allElements[i] = ElementInfo(id, rarity, discovered, userBalance);
        }

        return allElements;
    }

    function getUserElements(address user) external view returns (ElementInfo[] memory) {
        uint256[] memory balances = new uint256[](MAX_ELEMENT_ID + 1);
        uint256 ownedCount = 0;

        // Get balances in batches to avoid gas limits
        for (uint256 i = 0; i <= MAX_ELEMENT_ID; i += 100) {
            uint256 endIndex = Math.min(i + 100, MAX_ELEMENT_ID + 1);
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

        for (uint256 i = 0; i <= MAX_ELEMENT_ID; i++) {
            if (balances[i] > 0) {
                (uint256 id, uint256 rarity, bool discovered) = game.elements(i);
                ownedElements[index] = ElementInfo(id, rarity, discovered, balances[i]);
                index++;
            }
        }

        return ownedElements;
    }

    function getPossibleCombinations(uint256 elementId) external view returns (uint256[] memory) {
        uint256 elementCount = game.totalNFT();
        uint256[] memory possibleCombinations = new uint256[](elementCount);
        uint256 count = 0;

        for (uint256 i = 0; i < elementCount; i++) {
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

    function getElementFee(uint256 elementId) external view returns (uint256) {
        (,uint256 rarity,) = game.elements(elementId);
        return game.calculateFee(rarity);
    }

    function getTotalDiscoveredElements() external view returns (uint256) {
        uint256 elementCount = game.totalNFT();
        uint256 discoveredCount = 0;

        for (uint256 i = 0; i < elementCount; i++) {
            (,,bool discovered) = game.elements(i);
            if (discovered) {
                discoveredCount++;
            }
        }

        return discoveredCount;
    }
}