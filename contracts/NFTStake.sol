// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract NFTStake is ERC1155Holder, Ownable, ReentrancyGuard, Pausable {
    using Math for uint256;

    struct Stake {
        uint128 id;
        uint128 amount;
        uint128 stakedAt;
        uint128 lastClaimed;
    }

    IERC1155 public nftContract;
    IERC20 public rewardToken;
    uint256 public limitId;
    uint256 public rewardPerBlock;
    uint256 public totalStaked;
    uint256 public lastUpdateBlock;
    uint256 public constant BLOCKS_PER_DAY = 5760; // assuming 15s block time
    uint256 public constant MIN_STAKE_AMOUNT = 1;
    uint256 public constant UNSTAKE_COOLDOWN = 1 days;
    uint256 public maxStakePerUser = 100; // Example max stake limit

    mapping(address => mapping(uint256 => Stake)) public stakes;
    mapping(address => uint256[]) public userStakeIds;
    mapping(address => uint256) public stakedBalance;

    event Staked(address indexed user, uint256 indexed tokenId, uint256 amount);
    event Unstaked(address indexed user, uint256 indexed tokenId, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event ClaimBox(address indexed user, uint256 amount, uint256 index);

    constructor(IERC1155 _nftContract, IERC20 _rewardToken, uint256 _rewardPerBlock) Ownable(msg.sender) {
        nftContract = _nftContract;
        rewardToken = _rewardToken;
        rewardPerBlock = _rewardPerBlock;
        limitId = 4;
        lastUpdateBlock = block.number;
    }

    function stake(uint256 _id, uint256 _amount) external whenNotPaused nonReentrant {
        require(_amount >= MIN_STAKE_AMOUNT, "NFTStaking: amount too low");
        require(nftContract.balanceOf(msg.sender, _id) >= _amount, "NFTStaking: insufficient balance");
        require(nftContract.isApprovedForAll(msg.sender, address(this)), "NFTStaking: not approved");
        require(_id >= limitId, "not stakable");
        require(stakedBalance[msg.sender] + _amount <= maxStakePerUser, "Exceeds max stake limit");

        nftContract.safeTransferFrom(msg.sender, address(this), _id, _amount, "");

        Stake storage userStake = stakes[msg.sender][_id];
        if (userStake.amount > 0) {
            userStake.amount += uint128(_amount);
        } else {
            stakes[msg.sender][_id] = Stake({
                id: uint128(_id),
                amount: uint128(_amount),
                stakedAt: uint128(block.timestamp),
                lastClaimed: uint128(block.timestamp)
            });
            userStakeIds[msg.sender].push(_id);
        }

        stakedBalance[msg.sender] += _amount;
        totalStaked += _amount;

        emit Staked(msg.sender, _id, _amount);
    }

    function unstake(uint256 _id) external nonReentrant {
        Stake storage userStake = stakes[msg.sender][_id];
        require(userStake.amount > 0, "NFTStaking: no stake found");
        require(block.timestamp >= userStake.stakedAt + UNSTAKE_COOLDOWN, "Cooldown period not over");

        uint256 totalAmount = userStake.amount;
        uint256 totalReward = calculateReward(msg.sender, _id);

        delete stakes[msg.sender][_id];
        stakedBalance[msg.sender] -= totalAmount;
        totalStaked -= totalAmount;

        if (totalReward > 0) {
            rewardToken.transfer(msg.sender, totalReward);
        }
        nftContract.safeTransferFrom(address(this), msg.sender, _id, totalAmount, "");

        emit Unstaked(msg.sender, _id, totalAmount);
        emit Claimed(msg.sender, totalReward);
    }

    function claimRewards() external nonReentrant {
        uint256 totalReward = 0;
        for (uint256 i = 0; i < userStakeIds[msg.sender].length; i++) {
            uint256 id = userStakeIds[msg.sender][i];
            Stake storage userStake = stakes[msg.sender][id];
            if (userStake.amount > 0) {
                uint256 reward = calculateReward(msg.sender, id);
                totalReward += reward;
                userStake.lastClaimed = uint128(block.timestamp);
            }
        }

        require(totalReward > 0, "NFTStaking: no rewards to claim");
        rewardToken.transfer(msg.sender, totalReward);
        emit Claimed(msg.sender, totalReward);
    }

    function calculateReward(address _user, uint256 _id) public view returns (uint256) {
        Stake storage userStake = stakes[_user][_id];
        if (userStake.amount == 0) return 0;

        uint256 timePassed = block.timestamp - userStake.lastClaimed;
        uint256 rewardBlocks = timePassed / 15; // Assuming 15 second block time
        rewardBlocks = Math.min(rewardBlocks, BLOCKS_PER_DAY);

        uint256 rewardPercentage = getRewardPercentage(_id);
        uint256 reward = Math.mulDiv(rewardBlocks * rewardPerBlock, userStake.amount * rewardPercentage, totalStaked * 100);

        return reward;
    }

    function getRewardPercentage(uint256 _id) public pure returns (uint256) {
        if (_id <= 20) return 25;
        if (_id == 21) return 50;
        if (_id == 22) return 75;
        if (_id == 23) return 100;
        return 0;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setMaxStakePerUser(uint256 _maxStake) external onlyOwner {
        maxStakePerUser = _maxStake;
    }
    
    function getUserStakeIds(address _user) public view returns (uint256[] memory) {
        return userStakeIds[_user];
    }

    function depositRewards(uint256 _amount) external onlyOwner {
        rewardToken.transfer(address(this), _amount);
    }

    function withdrawRewards(uint256 _amount) external onlyOwner {
        require(rewardToken.balanceOf(address(this)) >= _amount, "Insufficient reward token balance");
        rewardToken.transfer(msg.sender, _amount);
    }
    
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }

    function recoverERC1155(address tokenAddress, uint256 tokenId, uint256 amount) external onlyOwner {
        IERC1155(tokenAddress).safeTransferFrom(address(this), owner(), tokenId, amount, "");
    }
}
