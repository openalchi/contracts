// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AlchemyGameUpgradeableV2.sol";
import "./AlchemyTournament.sol";

contract AlchemyGovernance is Initializable, OwnableUpgradeable {
    struct ElementListing {
        address lister;
        uint256 feePaid;
        uint256 totalVotes;
        mapping(address => uint256) voterShares;
        mapping(address => bool) hasVoted;
        address[] voters;
        bool isActive;
    }

    struct Epoch {
        uint256 startTime;
        uint256 endTime;
        uint256 totalRewardPool;
        uint256[] elementIds;
        uint256[] winners;
        mapping(uint256 => ElementListing) elements;
        bool isFinalized;
    }

    IERC20 public rewardToken;
    AlchemyGameUpgradeableV2 public game;
    AlchemyTournament public tournament;
    
    uint256 public constant BONUS_PERCENTAGE = 50;
    uint256 public epochDuration;
    uint256 public currentEpoch;
    uint256 public minimumListingFee;
    bool public paused;
    uint256 public constant FEE_DECAY = 10;
    
    mapping(uint256 => Epoch) public epochs;
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public voterRewards;

    event ElementListed(address indexed lister, uint256 elementId, uint256 fee);
    event Voted(address indexed voter, uint256 indexed epoch, uint256 elementId, uint256 amount);
    event EpochFinalized(uint256 indexed epoch, uint256[] winningElements);
    event RewardsDeposited(uint256 amount);
    event RewardsWithdrawn(uint256 amount);
    event VoteCancelled(address indexed voter, uint256 indexed epoch, uint256 elementId, uint256 amount);

    function initialize(
        address _game,
        address _tournament,
        address _rewardToken,
        uint256 _epochDuration,
        uint256 _minimumFee
    ) public initializer {
        __Ownable_init(msg.sender);
        game = AlchemyGameUpgradeableV2(_game);
        tournament = AlchemyTournament(_tournament);
        rewardToken = IERC20(_rewardToken);
        epochDuration = _epochDuration;
        minimumListingFee = _minimumFee;
        currentEpoch = 1;
        
        epochs[1].startTime = block.timestamp;
        epochs[1].endTime = block.timestamp + epochDuration;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function listElement(uint256 elementId, uint256 fee) external whenNotPaused {
        require(fee >= minimumListingFee, "Fee too low");
        (, , bool discovered, , ) = game.elements(elementId);
        require(discovered, "Element not found");
        
        uint256 nextEpoch = currentEpoch + 1;
        require(!epochs[nextEpoch].isFinalized, "Epoch closed");
        
        ElementListing storage element = epochs[nextEpoch].elements[elementId];
        require(element.lister == address(0), "Element already listed");

        rewardToken.transferFrom(msg.sender, address(this), fee);

        element.lister = msg.sender;
        element.feePaid = fee;
        element.totalVotes = 0;
        element.isActive = true;
        element.voters = new address[](0);

        epochs[nextEpoch].elementIds.push(elementId);
        epochs[nextEpoch].totalRewardPool += fee;
        emit ElementListed(msg.sender, elementId, fee);
    }

    function vote(uint256 elementId, uint256 votingPower) external whenNotPaused {
        Epoch storage epoch = epochs[currentEpoch];
        require(block.timestamp <= epoch.endTime, "Voting period ended");
        
        ElementListing storage element = epoch.elements[elementId];
        require(element.isActive, "Invalid element");
        require(votingPower > 0, "Voting power must > 0");

        rewardToken.transferFrom(msg.sender, address(this), votingPower);

        if (!element.hasVoted[msg.sender]) {
            element.voters.push(msg.sender);
            element.hasVoted[msg.sender] = true;
        }
        
        element.totalVotes += votingPower;
        element.voterShares[msg.sender] += votingPower;
        emit Voted(msg.sender, currentEpoch, elementId, votingPower);
    }

    function cancelVote(uint256 elementId) external whenNotPaused {
        Epoch storage epoch = epochs[currentEpoch];
        require(block.timestamp <= epoch.endTime, "Voting ended");
        
        ElementListing storage element = epoch.elements[elementId];
        require(element.isActive, "Element not active");
        
        uint256 voterShare = element.voterShares[msg.sender];
        require(voterShare > 0, "No vote");
        
        element.totalVotes -= voterShare;
        element.voterShares[msg.sender] = 0;
        rewardToken.transfer(msg.sender, voterShare);
        
        emit VoteCancelled(msg.sender, currentEpoch, elementId, voterShare);
    }

   
    function finalizeEpoch() external onlyOwner {
        Epoch storage epoch = epochs[currentEpoch];
        require(block.timestamp > epoch.endTime, "Epoch ongoing");
        require(!epoch.isFinalized, "Already finalized");

        if (epoch.elementIds.length == 0) {
            // No elements: Finalize and reset
            epoch.isFinalized = true;
            _setupNextEpoch(new uint256[](0));
            emit EpochFinalized(currentEpoch, new uint256[](0));
            currentEpoch++;
            return;
        }

        uint256[] memory winners = _selectTopElements(3);
        epoch.winners = winners;

        // Calculate total votes from winners
        uint256 totalVotes;
        for (uint256 i = 0; i < winners.length; i++) {
            totalVotes += epochs[currentEpoch].elements[winners[i]].totalVotes;
        }

        if (totalVotes == 0) {
            // No votes: Skip distribution, finalize, and carry over elements
            _setupNextEpoch(winners);
            epoch.isFinalized = true;
            emit EpochFinalized(currentEpoch, winners);
            currentEpoch++;
            return;
        } else {
            // Distribute rewards as usual
            uint256 bonusRewards = (epoch.totalRewardPool * BONUS_PERCENTAGE) / 100;
            uint256 totalRewards = epoch.totalRewardPool + bonusRewards;
            _distributeRewards(winners, totalRewards);
            _setupNextEpoch(winners);
        }

        epoch.isFinalized = true;
        emit EpochFinalized(currentEpoch, winners);
        currentEpoch++;
    }


    function _selectTopElements(uint256 count) internal view returns (uint256[] memory) {
        uint256[] memory elements = epochs[currentEpoch].elementIds;
        uint256 loopCount = count;
        if (elements.length < loopCount) {
            loopCount = elements.length;
        }
        uint256[] memory winners = new uint256[](loopCount); // Adjust winners array length
        uint256[] memory votes = new uint256[](elements.length);

        // Collect votes
        for (uint256 i = 0; i < elements.length; i++) {
            votes[i] = epochs[currentEpoch].elements[elements[i]].totalVotes;
        }

        // Simple selection sort up to loopCount
        for (uint256 i = 0; i < loopCount; i++) {
            uint256 maxIndex = i;
            for (uint256 j = i + 1; j < elements.length; j++) {
                if (votes[j] > votes[maxIndex]) {
                    maxIndex = j;
                }
            }
            if (maxIndex != i && votes[maxIndex] > 0) {
                (elements[i], elements[maxIndex]) = (elements[maxIndex], elements[i]);
                (votes[i], votes[maxIndex]) = (votes[maxIndex], votes[i]);
            }
            winners[i] = elements[i];
        }
        return winners;
    }

    function _distributeRewards(uint256[] memory winners, uint256 totalRewards) internal {
        uint256 totalVotes;
        for (uint256 i = 0; i < winners.length; i++) {
            totalVotes += epochs[currentEpoch].elements[winners[i]].totalVotes;
        }
        require(totalVotes > 0, "No votes");
        
        for (uint256 i = 0; i < winners.length; i++) {
            ElementListing storage element = epochs[currentEpoch].elements[winners[i]];
            uint256 elementReward = (totalRewards * element.totalVotes) / totalVotes;
            uint256 voterRewardsTotal = (elementReward * 80) / 100;
            
            for (uint256 j = 0; j < element.voters.length; j++) {
                address voter = element.voters[j];
                uint256 share = (element.voterShares[voter] * voterRewardsTotal) / element.totalVotes;
                if (share > 0) {
                    voterRewards[currentEpoch][winners[i]][voter] += share;
                }
            }
            
            if (elementReward - voterRewardsTotal > 0) {
                rewardToken.transfer(element.lister, elementReward - voterRewardsTotal);
            }
        }
    }

    function claimVoterRewards(uint256 epoch, uint256 elementId) external {
        uint256 amount = voterRewards[epoch][elementId][msg.sender];
        require(amount > 0, "No rewards");
        
        voterRewards[epoch][elementId][msg.sender] = 0;
        rewardToken.transfer(msg.sender, amount);
    }

    function depositRewards(uint256 amount) external onlyOwner {
        rewardToken.transferFrom(msg.sender, address(this), amount);
        emit RewardsDeposited(amount);
    }

    function withdrawExcessRewards(uint256 amount) external onlyOwner {
        uint256 contractBalance = rewardToken.balanceOf(address(this));
        uint256 lockedRewards = _calculateLockedRewards();
        require(contractBalance - lockedRewards >= amount, "Insufficient funds");
        
        rewardToken.transfer(owner(), amount);
        emit RewardsWithdrawn(amount);
    }

    // Getters
    function getEpochElements(uint256 epoch) external view returns (uint256[] memory) {
        return epochs[epoch].elementIds;
    }

    function getEpochWinners(uint256 epoch) external view returns (uint256[] memory) {
        require(epoch <= currentEpoch, "Invalid epoch");
        require(epochs[epoch].isFinalized, "Epoch not finalized");
        return epochs[epoch].winners;
    }

    function getVoterShare(address voter, uint256 epoch, uint256 elementId) external view returns (uint256) {
        return epochs[epoch].elements[elementId].voterShares[voter];
    }

    function getElementDetails(uint256 epoch, uint256 elementId) public view returns (
        address lister,
        uint256 feePaid,
        uint256 totalVotes,
        bool isActive
        ) {
        ElementListing storage listing = epochs[epoch].elements[elementId];
        return (listing.lister, listing.feePaid, listing.totalVotes, listing.isActive);
    }

    function getElementVoters(uint256 epoch, uint256 elementId) public view returns (address[] memory) {
        return epochs[epoch].elements[elementId].voters;
    }

    function hasVoted(uint256 epoch, uint256 elementId, address voter) public view returns (bool) {
        return epochs[epoch].elements[elementId].hasVoted[voter];
    }

    function getVoterShares(uint256 epoch, uint256 elementId, address voter) public view returns (uint256) {
        return epochs[epoch].elements[elementId].voterShares[voter];
    }

    function _setupNextEpoch(uint256[] memory winners) internal {
        uint256 nextEpoch = currentEpoch + 1;
        epochs[nextEpoch].startTime = block.timestamp;
        epochs[nextEpoch].endTime = block.timestamp + epochDuration;

        for (uint256 i = 0; i < epochs[currentEpoch].elementIds.length; i++) {
            uint256 elementId = epochs[currentEpoch].elementIds[i];
            bool isWinner = false;
            
            for (uint256 j = 0; j < winners.length; j++) {
                if (winners[j] == elementId) {
                    isWinner = true;
                    break;
                }
            }
            
            if (!isWinner) {
                ElementListing storage currentElement = epochs[currentEpoch].elements[elementId];
                ElementListing storage newElement = epochs[nextEpoch].elements[elementId];
                
                // Only carry over if not already listed
                if (newElement.lister == address(0)) {
                    newElement.lister = currentElement.lister;
                    newElement.feePaid = currentElement.feePaid * (100 - FEE_DECAY) / 100;
                    newElement.isActive = true;
                    newElement.totalVotes = 0;
                    newElement.voters = new address[](0);
                    
                    epochs[nextEpoch].elementIds.push(elementId);
                    epochs[nextEpoch].totalRewardPool += newElement.feePaid;
                }
            }
        }
    }

    function _calculateLockedRewards() internal view returns (uint256) {
        uint256 locked;
        for (uint256 i = 1; i <= currentEpoch; i++) {
            if (!epochs[i].isFinalized) {
                locked += epochs[i].totalRewardPool;
            }
        }
        return locked;
    }
}