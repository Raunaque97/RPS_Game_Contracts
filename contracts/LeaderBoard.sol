// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract LeaderBoard {
    // leaderBoard[0] is the best player &  0>1>2>3>4
    address[5] public leaderBoard;

    function getScore(address player) internal view virtual returns (uint);

    function getLeaderBoard() public view virtual returns (address[5] memory) {
        return leaderBoard;
    }

    function updateLeaderBoard(address player, uint score) internal {
        uint i = 0;
        while (i < 5) {
            if (leaderBoard[i] == address(0)) {
                leaderBoard[i] = player;
                break;
            }
            if (leaderBoard[i] == player) {
                break;
            }
            if (score > getScore(leaderBoard[i])) {
                for (uint j = 4; j > i; j--) {
                    leaderBoard[j] = leaderBoard[j - 1];
                }
                leaderBoard[i] = player;
                break;
            }
            i++;
        }
    }
}
