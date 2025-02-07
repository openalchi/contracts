// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AlchemyGameUpgradeableV2.sol";

interface IAlchemyGovernance {
    function currentEpoch() external view returns (uint256);
    function getEpochWinners(uint256 epoch) external view returns (uint256[] memory);
}

contract AlchemyTournament is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, IERC1155Receiver {

    struct StakingSession {
        uint256 startTime;
        uint256 endTime;
        uint256 totalRewards;
        uint256 totalStaked;
        mapping(uint256 => uint256) elementStakes; 
        mapping(address => mapping(uint256 => uint256)) userStakes; 
        mapping(uint256 => bool) validElements; 
        uint256[] winners;
        mapping(address => uint256) claimedRewards;
        mapping(address => mapping(uint256 => uint256)) userStakeTime;
    }

    AlchemyGameUpgradeableV2 public gameNFT;
    IERC20 public rewardToken;
    IAlchemyGovernance public governance;
    
    uint256 public currentSession;
    uint256 public sessionDuration;
    uint256 public governanceEpochOffset;
    
    mapping(uint256 => StakingSession) public sessions;

    event SessionStarted(uint256 sessionId, uint256[] elements);
    event Staked(address indexed user, uint256 sessionId, uint256 elementId, uint256 amount);
    event Withdrawn(address indexed user, uint256 sessionId, uint256 elementId, uint256 amount);
    event RewardsDeposited(uint256 sessionId, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 sessionId, uint256 amount);

    function initialize(
        address _gameNFT,
        address _rewardToken,
        address _governance,
        uint256 _sessionDuration,
        uint256 _epochOffset
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        gameNFT = AlchemyGameUpgradeableV2(_gameNFT);
        rewardToken = IERC20(_rewardToken);
        governance = IAlchemyGovernance(_governance);
        sessionDuration = _sessionDuration;
        governanceEpochOffset = _epochOffset;
    }

    function startNewSession() external onlyOwner {
        uint256 governanceEpoch = governance.currentEpoch() - governanceEpochOffset;
        uint256[] memory winners = governance.getEpochWinners(governanceEpoch);
        
        currentSession++;
        StakingSession storage session = sessions[currentSession];
        
        session.startTime = block.timestamp;
        session.endTime = block.timestamp + sessionDuration;
        
        for (uint256 i = 0; i < winners.length; i++) {
            uint256 elementId = winners[i];
            session.validElements[elementId] = true;
            session.winners.push(elementId);
        }
        
        emit SessionStarted(currentSession, winners);
    }

    function stake(uint256 elementId, uint256 amount) external {
        StakingSession storage session = sessions[currentSession];
        require(block.timestamp < session.endTime, "Session ended");
        require(session.validElements[elementId], "Invalid element");
        
        gameNFT.safeTransferFrom(msg.sender, address(this), elementId, amount, "");
        
        uint256 prevStake = session.userStakes[msg.sender][elementId];
        if (prevStake == 0) {
            session.userStakeTime[msg.sender][elementId] = block.timestamp;
        } else {
            uint256 oldTime = session.userStakeTime[msg.sender][elementId];
            uint256 newStake = prevStake + amount;
            session.userStakeTime[msg.sender][elementId] = (prevStake * oldTime + amount * block.timestamp) / newStake;
        }
        
        session.elementStakes[elementId] += amount;
        session.userStakes[msg.sender][elementId] += amount;
        session.totalStaked += amount;
        
        emit Staked(msg.sender, currentSession, elementId, amount);
    }

    function depositRewards(uint256 sessionId, uint256 amount) external onlyOwner {
        require(sessionId <= currentSession, "Invalid session");
        rewardToken.transferFrom(msg.sender, address(this), amount);
        
        sessions[sessionId].totalRewards += amount;
        emit RewardsDeposited(sessionId, amount);
    }

    function claimRewards(uint256 sessionId) external {
        uint256 claimable = _calculateClaimable(msg.sender, sessionId);
        require(claimable > 0, "No rewards");
        sessions[sessionId].claimedRewards[msg.sender] += claimable;
        rewardToken.transfer(msg.sender, claimable);
        emit RewardsClaimed(msg.sender, sessionId, claimable);
    }

    function claimRewardsAndWithdraw(uint256 sessionId) external nonReentrant {
        StakingSession storage session = sessions[sessionId];
        require(block.timestamp > session.endTime, "Session ongoing");

        uint256 claimable = _calculateClaimable(msg.sender, sessionId);
        require(claimable > 0, "No rewards");
        session.claimedRewards[msg.sender] += claimable;
        rewardToken.transfer(msg.sender, claimable);
        emit RewardsClaimed(msg.sender, sessionId, claimable);
        
        for (uint256 i = 0; i < session.winners.length; i++) {
            uint256 elementId = session.winners[i];
            uint256 stakedAmount = session.userStakes[msg.sender][elementId];
            if (stakedAmount > 0) {
                session.userStakes[msg.sender][elementId] = 0;
                session.elementStakes[elementId] -= stakedAmount;
                session.totalStaked -= stakedAmount;
                gameNFT.safeTransferFrom(address(this), msg.sender, elementId, stakedAmount, "");
                emit Withdrawn(msg.sender, sessionId, elementId, stakedAmount);
            }
        }
    }

    function _calculateClaimable(address user, uint256 sessionId) internal view returns (uint256) {
        StakingSession storage session = sessions[sessionId];
        require(session.totalStaked > 0, "No stakes");
        uint256 totalEntitlement = 0;
        uint256 duration = session.endTime - session.startTime;
        // Loop over all valid (winner) elements.
        for (uint256 i = 0; i < session.winners.length; i++) {
            uint256 elementId = session.winners[i];
            uint256 stake = session.userStakes[user][elementId];
            if (stake > 0) {
                uint256 depositTime = session.userStakeTime[user][elementId];
                uint256 heldDuration = session.endTime > depositTime ? (session.endTime - depositTime) : 0;
                // Compute a duration factor scaled by 1e18 (between 0 and 1e18)
                uint256 durationFactor = (heldDuration * 1e18) / duration;
                uint256 weightedStake = (stake * durationFactor) / 1e18;
                totalEntitlement += (weightedStake * session.totalRewards) / session.totalStaked;
            }
        }
        // Subtract any rewards already claimed.
        if (totalEntitlement <= session.claimedRewards[user]) {
            return 0;
        }
        return totalEntitlement - session.claimedRewards[user];
    }

    function getSessionElements(uint256 sessionId) external view returns (uint256[] memory) {
        StakingSession storage session = sessions[sessionId];
        return session.winners;
    }

    function getSessionInfo(uint256 sessionId) public view returns (
        uint256 startTime,
        uint256 endTime,
        uint256 totalRewards,
        uint256 totalStaked
    ) {
        StakingSession storage session = sessions[sessionId];
        return (session.startTime, session.endTime, session.totalRewards, session.totalStaked);
    }
    
    function getUserStake(
        uint256 sessionId,
        address user,
        uint256 elementId
    ) external view returns (uint256) {
        return sessions[sessionId].userStakes[user][elementId];
    }

     // IERC1155Receiver interface implementations.
    function onERC1155Received(
        address, /* operator */
        address, /* from */
        uint256, /* id */
        uint256, /* value */
        bytes memory /* data */
    ) public pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address, /* operator */
        address, /* from */
        uint256[] memory, /* ids */
        uint256[] memory, /* values */
        bytes memory /* data */
    ) public pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /// @notice Implementation of ERC165's supportsInterface.

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }
    
    /// @notice Recover any ERC20 tokens mistakenly sent to the contract.
    
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }

    /// @notice Recover any ERC1155 tokens mistakenly sent to the contract.
    function recoverERC1155(address tokenAddress, uint256 tokenId, uint256 amount) external onlyOwner {
        IERC1155(tokenAddress).safeTransferFrom(address(this), owner(), tokenId, amount, "");
    }
}
