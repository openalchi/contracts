// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "./NFTStake.sol"; // Import your main contract

contract NFTStakeHelper {
    using Math for uint256;

    NFTStake public stakeContract;

    constructor(address _stakeContract) {
        stakeContract = NFTStake(_stakeContract);
    }

    function getUserStakes(address _user) external view returns (NFTStake.Stake[] memory) {
        uint256[] memory stakeIds = stakeContract.getUserStakeIds(_user);
        uint256 totalStakes = stakeIds.length;

        NFTStake.Stake[] memory userStakes = new NFTStake.Stake[](totalStakes);

        for (uint256 i = 0; i < stakeIds.length; i++) {
            uint256 id = stakeIds[i];
            (uint128 stakeId, uint128 amount, uint128 stakedAt, uint128 lastClaimed) = stakeContract.stakes(_user, id);
            userStakes[i] = NFTStake.Stake(stakeId, amount, stakedAt, lastClaimed);
        }

        return userStakes;
    }

    function getTotalRewards(address _user) external view returns (uint256) {
        uint256[] memory stakeIds = stakeContract.getUserStakeIds(_user);
        uint256 totalReward = 0;

        for (uint256 i = 0; i < stakeIds.length; i++) {
            uint256 id = stakeIds[i];
            totalReward += stakeContract.calculateReward(_user, id);
        }

        return totalReward;
    }

    function getStakingStats() external view returns (uint256 totalStaked, uint256 totalRewardsAvailable) {
        totalStaked = stakeContract.totalStaked();
        totalRewardsAvailable = stakeContract.rewardToken().balanceOf(address(stakeContract));
    }

    function getRewardRate(uint256 _id) external view returns (uint256) {
        uint256 rewardPercentage = stakeContract.getRewardPercentage(_id);
        uint256 rewardPerBlock = stakeContract.rewardPerBlock();
        return Math.mulDiv(rewardPerBlock, rewardPercentage, 100);
    }

    // Add more view functions as needed for your UI
}

