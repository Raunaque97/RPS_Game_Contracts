// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract LeaderBoard {
    // leaderBoard[0] is the best player &  0>1>2>3>4
    mapping(uint => address[5]) private leaderBoard;
    uint private counter;

    function getScore(address player) internal view virtual returns (uint);

    function getLeaderBoard() public view virtual returns (address[5] memory) {
        return leaderBoard[counter];
    }

    function getLeaderBoard(uint historical) public view virtual returns (address[5] memory) {
        return leaderBoard[historical];
    }

    function updateLeaderBoard(address player, uint score) internal {
        uint i = 0;
        while (i < 5) {
            if (leaderBoard[counter][i] == address(0)) {
                leaderBoard[counter][i] = player;
                break;
            }
            if (leaderBoard[counter][i] == player) {
                break;
            }
            if (score > getScore(leaderBoard[counter][i])) {
                for (uint j = 4; j > i; j--) {
                    leaderBoard[counter][j] = leaderBoard[counter][j - 1];
                }
                leaderBoard[counter][i] = player;
                break;
            }
            i++;
        }
    }

    function startNewLeaderBoard() internal {
        counter++;
    }
}
