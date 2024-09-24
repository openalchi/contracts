// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "./NFTStakeUpgradeable.sol"; // Assuming the stake contract is upgradeable

contract NFTStakeHelperUpdateable {
    using Math for uint256;

    NFTStakeUpgradeable public stakeContract;

    constructor(address _stakeContract) {
        stakeContract = NFTStakeUpgradeable(_stakeContract);
    }

    // Fetch all stakes of a user
    function getUserStakes(address _user) external view returns (NFTStakeUpgradeable.Stake[] memory) {
        uint256[] memory stakeIds = stakeContract.getUserStakeIds(_user);
        uint256 totalStakes = stakeIds.length;

        NFTStakeUpgradeable.Stake[] memory userStakes = new NFTStakeUpgradeable.Stake[](totalStakes);

        for (uint256 i = 0; i < totalStakes; i++) {
            uint256 id = stakeIds[i];
            (uint128 stakeId, uint128 amount, uint128 stakedAt, uint128 lastClaimed) = stakeContract.stakes(_user, id);
            userStakes[i] = NFTStakeUpgradeable.Stake(stakeId, amount, stakedAt, lastClaimed);
        }

        return userStakes;
    }

    // Calculate total rewards across all stakes of a user
    function getTotalRewards(address _user) external view returns (uint256) {
        uint256[] memory stakeIds = stakeContract.getUserStakeIds(_user);
        uint256 totalReward = 0;

        for (uint256 i = 0; i < stakeIds.length; i++) {
            uint256 id = stakeIds[i];
            totalReward += stakeContract.calculateReward(_user, id);
        }

        return totalReward;
    }

    // Fetch staking statistics
    function getStakingStats() external view returns (uint256 totalStaked, uint256 totalRewardsAvailable) {
        totalStaked = stakeContract.totalStaked();
        totalRewardsAvailable = stakeContract.rewardToken().balanceOf(address(stakeContract));
    }

    // Fetch reward rate for a specific element ID
    function getRewardRate(uint256 _id) external view returns (uint256) {
        uint256 rewardPercentage = stakeContract.getRewardPercentage(_id);
        uint256 rewardPerBlock = stakeContract.rewardPerBlock();
        return Math.mulDiv(rewardPerBlock, rewardPercentage, 100);
    }

}
