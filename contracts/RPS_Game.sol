// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

import {InitVerifier} from "./verifiers/initVerifier.sol";
import {MoveAVerifier} from "./verifiers/moveAVerifier.sol";
import {MoveBVerifier} from "./verifiers/moveBVerifier.sol";
import {GameWallet} from "./GameWallet.sol";
import {LeaderBoard} from "./LeaderBoard.sol";

contract RPS_Game is Ownable, KeeperCompatibleInterface, LeaderBoard {
    GameWallet public gameWallet;

    struct Player {
        address proxyAddress;
        uint gameId; // note that this is not updated when the last game is finalized
        uint32 wins;
        uint32 losses;
        uint32 streak;
    }
    struct Game {
        uint startedAt;
        uint finalizedAt;
        uint wager;
        address[2] PlayerAddrs;
        address[2] PlayerProxyAddrs;
    }
    enum FinalizeType {
        Normal,
        FraudProof,
        Timeout,
        Abandoned
    }

    mapping(address => Player) public players;
    mapping(uint => Game) private games;

    mapping(address => uint) public currTournamentScore; // score for current tournament

    uint public counter;
    uint public minWalletBal;

    uint public interval = 1 weeks;
    uint public gameRewardPercent = 500000; // == 50%  between [0, 1000000]
    uint public lastUpkeepTime; // same as when last tournament ended
    // define a random address
    address public treasuryAddr = address(bytes20(keccak256("GameTreasuryAddress")));

    // EVENTS
    event GameStarted(
        uint indexed gameId,
        address indexed player0,
        address indexed player1,
        address player0Proxy,
        address player1Proxy,
        uint wager
    );
    event GameFinalized(
        uint indexed gameId,
        address indexed player0,
        address indexed player1,
        uint winner, // 3 means abadoned
        uint wager,
        FinalizeType way
    );

    event TournamentWin(address indexed player, uint timestamp, uint reward);

    constructor(address _walletAddrs, uint _minWalletBal) {
        gameWallet = GameWallet(_walletAddrs);
        minWalletBal = _minWalletBal;
        lastUpkeepTime = block.timestamp;
    }

    // TODO
    // function forceMove() public {
    // }

    // function forceMoveReply() public {
    // }

    // function timeOutWin() public {
    // }

    // function fraudProofWin() public {
    // }

    function finalizeAbandonedGame(address _player0Addrs, address _player1Addrs) public onlyOwner {
        players[_player0Addrs].proxyAddress = address(0);
        players[_player1Addrs].proxyAddress = address(0);

        uint gameId = players[_player0Addrs].gameId;
        require(gameId > 0, "invalid game id");
        require(gameId == players[_player1Addrs].gameId, "invalid game id");

        Game storage game = games[gameId];
        require(block.timestamp >= game.startedAt + 1 days, "game not Abandoned");
        require(game.finalizedAt == 0, "game already finalized");

        game.finalizedAt = block.timestamp;
        // emit event
        emit GameFinalized(
            gameId,
            game.PlayerAddrs[0],
            game.PlayerAddrs[1],
            3,
            game.wager,
            FinalizeType.Abandoned
        );
    }

    /**
        player0 proposes a game by signing a message.
        anyone can call this function to start a game with player0.
        player1 is msg.sender.
     */
    function startGame(
        address _player0Addrs,
        address _player0ProxyAddrs,
        address _player1ProxyAddrs,
        uint wager,
        uint validUntil,
        bytes calldata signature0 // player0's signature
    ) public {
        // calculate message hash from _playerAddrs[0], _playerProxyAddrs[0], wager, validUntil, and verify
        bytes32 calculatedHash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(_player0Addrs, _player0ProxyAddrs, wager, validUntil))
        );
        // verify signatures
        require(
            ECDSA.recover(calculatedHash, signature0) == _player0Addrs,
            "Player0 signature invalid"
        );
        require(_player0Addrs != msg.sender, "player0 cannot be player1");
        // verify validUntil
        require(validUntil >= block.timestamp, "timeout");
        // verify players have enough security deposit
        require(
            gameWallet.deposits(_player0Addrs) >= minWalletBal &&
                gameWallet.deposits(msg.sender) >= minWalletBal &&
                gameWallet.deposits(_player0Addrs) >= wager &&
                gameWallet.deposits(msg.sender) >= wager,
            "player does not have enough deposit"
        );
        // verify player not already in a game, players proxy addresses should be set to 0x0
        require(players[_player0Addrs].proxyAddress == address(0), "player0 already in a game");
        require(players[msg.sender].proxyAddress == address(0), "player1 already in a game");

        players[_player0Addrs].proxyAddress = _player0ProxyAddrs;

        // tounament score reset
        // players[_player0Addrs].gameId  will contain the gameId of the last game played
        // check if it belongs to the last tournament
        if (games[players[_player0Addrs].gameId].startedAt < lastUpkeepTime) {
            currTournamentScore[_player0Addrs] = 0;
        }
        if (games[players[msg.sender].gameId].startedAt < lastUpkeepTime) {
            currTournamentScore[msg.sender] = 0;
        }

        players[msg.sender].proxyAddress = _player1ProxyAddrs;

        // create a new game
        counter += 1;
        players[_player0Addrs].gameId = counter;
        players[msg.sender].gameId = counter;
        games[counter].startedAt = block.timestamp;
        games[counter].wager = wager;
        games[counter].PlayerAddrs[0] = _player0Addrs;
        games[counter].PlayerAddrs[1] = msg.sender;
        games[counter].PlayerProxyAddrs[0] = _player0ProxyAddrs;
        games[counter].PlayerProxyAddrs[1] = _player1ProxyAddrs;
        // collect wagers
        if (wager > 0) {
            gameWallet.transfer(address(this), _player0Addrs, wager);
            gameWallet.transfer(address(this), msg.sender, wager);
        }
        // emit event
        emit GameStarted(
            counter,
            _player0Addrs,
            msg.sender,
            _player0ProxyAddrs,
            _player1ProxyAddrs,
            wager
        );
    }

    function finalizeGame(
        bytes calldata signature,
        // proof values
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[10] calldata input
    ) public {
        uint gameId = players[msg.sender].gameId;
        require(gameId > 0, "player not in a game");
        Game storage game = games[gameId];
        // verify game exists
        require(game.startedAt != 0 && game.finalizedAt == 0, "game does not exist");
        // verify proof is valid
        uint step = input[9];
        bytes32 prevStateHash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(input[2], input[3], input[4], input[5])) // TODO check if this is the correct way to hash
        );
        if (step & 1 == 0) {
            // msg.sender is player0 and should verify moveA, & prevStateHash should be signed by player1's proxy address
            require(MoveAVerifier.verifyProof(a, b, c, input), "invalid proof");
            // prev pub states should be signed by the opponent's proxy address
            require(
                ECDSA.recover(prevStateHash, signature) == game.PlayerProxyAddrs[1],
                "invalid signature"
            );
        } else {
            require(MoveBVerifier.verifyProof(a, b, c, input), "invalid proof");
            require(
                ECDSA.recover(prevStateHash, signature) == game.PlayerProxyAddrs[0],
                "invalid signature"
            );
        }
        // update games
        game.finalizedAt = block.timestamp;
        // update players
        address winner = game.PlayerAddrs[1];
        address loser = game.PlayerAddrs[0];
        if (input[7] == 0) {
            // player 0 wins
            winner = game.PlayerAddrs[0];
            loser = game.PlayerAddrs[1];
        }
        players[winner].wins += 1;
        players[winner].streak += 1;
        players[winner].proxyAddress = address(0);

        // tournament score update
        currTournamentScore[winner] += 1;
        updateLeaderBoard(winner, currTournamentScore[winner]);

        players[loser].losses += 1;
        players[loser].streak = 0;
        players[loser].proxyAddress = address(0);

        // grant rewards
        // calculate reward using gameRewardPercent
        uint reward = (game.wager * gameRewardPercent) / 1000000;
        gameWallet.transfer(winner, address(this), game.wager + reward);
        // send rest to treasuryAddr
        gameWallet.transfer(treasuryAddr, address(this), game.wager - reward);

        // emit event
        emit GameFinalized(
            gameId,
            game.PlayerAddrs[0],
            game.PlayerAddrs[1],
            input[7] == 0 ? 0 : 1,
            game.wager,
            FinalizeType.Normal
        );
    }

    function getScore(address player) internal view virtual override returns (uint) {
        return currTournamentScore[player];
    }

    function rewardTopPlayers() internal {
        address[5] memory topPlayers = getLeaderBoard(); // can contain address(0)
        // half of the treasury goes to the top player
        uint reward = (gameWallet.deposits(treasuryAddr) >> 1) / 5;
        for (uint i = 0; i < 5; i++) {
            if (topPlayers[i] == address(0)) continue;

            gameWallet.transfer(topPlayers[i], treasuryAddr, reward);
            // emit event
            emit TournamentWin(topPlayers[i], block.timestamp, reward);
        }
    }

    ////////////////// KEEPERS
    function checkUpkeep(
        bytes calldata
    ) external view override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = block.timestamp > lastUpkeepTime + interval;
        return (upkeepNeeded, bytes(""));
    }

    function performUpkeep(bytes calldata) external override {
        require(block.timestamp > lastUpkeepTime + interval, "too early");
        lastUpkeepTime = block.timestamp;
        rewardTopPlayers();
        startNewLeaderBoard();
    }

    //////////////////////////

    function getGame(uint id) public view returns (Game memory) {
        return games[id];
    }

    //  SETTERS
    function setMinWalletBal(uint _minWalletBal) public onlyOwner {
        minWalletBal = _minWalletBal;
    }

    function setInterval(uint _interval) public onlyOwner {
        interval = _interval;
    }

    function setGameRewardPercent(uint _gameRewardPercent) public onlyOwner {
        gameRewardPercent = _gameRewardPercent;
    }
}
