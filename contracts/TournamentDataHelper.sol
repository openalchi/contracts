// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AlchemyTournament.sol"; 
contract TournamentDataHelper {
    AlchemyTournament public tournament;

    constructor(address _tournamentAddress) {
        tournament = AlchemyTournament(_tournamentAddress);
    }

    struct SessionData {
        uint256 sessionId;
        uint256 startTime;
        uint256 endTime;
        uint256 totalRewards;
        uint256 totalStaked;
        uint256[] winners;
    }

    function getAllSessionsData() external view returns (SessionData[] memory) {
        uint256 currentSess = tournament.currentSession();
        SessionData[] memory sessionsData = new SessionData[](currentSess);

        for (uint256 i = 1; i <= currentSess; i++) {
            (
                uint256 startTime,
                uint256 endTime,
                uint256 totalRewards,
                uint256 totalStaked
            ) = tournament.getSessionInfo(i);
            uint256[] memory winners = tournament.getSessionElements(i);

            sessionsData[i - 1] = SessionData({
                sessionId: i,
                startTime: startTime,
                endTime: endTime,
                totalRewards: totalRewards,
                totalStaked: totalStaked,
                winners: winners
            });
        }
        return sessionsData;
    }
    
    function getUserStakesForSession(uint256 sessionId, address user)
        external
        view
        returns (uint256[] memory elementIds, uint256[] memory stakes)
    {
        uint256[] memory winners = tournament.getSessionElements(sessionId);
        uint256 length = winners.length;
        elementIds = new uint256[](length);
        stakes = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 elementId = winners[i];
            uint256 stakeAmount = tournament.getUserStake(sessionId, user, elementId);
            elementIds[i] = elementId;
            stakes[i] = stakeAmount;
        }
        return (elementIds, stakes);
    }
}
