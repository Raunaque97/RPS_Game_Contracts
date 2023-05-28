// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {InitVerifier} from "./verifiers/initVerifier.sol";
import {MoveAVerifier} from "./verifiers/moveAVerifier.sol";
import {MoveBVerifier} from "./verifiers/moveBVerifier.sol";
import {GameWallet} from "./GameWallet.sol";

contract RPS_Game is Ownable {
    GameWallet public gameWallet;

    struct Player {
        address proxyAddress;
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

    uint public counter;
    uint public minWalletBal;

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
        uint winner,
        uint wager,
        FinalizeType way
    );

    constructor(address _walletAddrs, uint _minWalletBal) {
        gameWallet = GameWallet(_walletAddrs);
        minWalletBal = _minWalletBal;
    }

    // function forceMove() public {
    // }

    // function forceMoveReply() public {
    // }

    // function timeOutWin() public {
    // }

    // function fraudProofWin() public {
    // }

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
        players[msg.sender].proxyAddress = _player1ProxyAddrs;
        // create a new game
        counter += 1;
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
        uint gameId,
        bytes calldata signature,
        // proof values
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[10] calldata input
    ) public {
        Game storage game = games[gameId];
        // verify game exists
        require(game.startedAt != 0 && game.finalizedAt == 0, "game does not exist");
        // verify proof is valid
        uint step = input[9];
        bytes32 prevStateHash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(input[1], input[2], input[3], input[4], input[5])) // TODO check if this is the correct way to hash
        );
        if (step & 1 == 0) {
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
            // TODO check if this is the correct index
            // player 0 wins
            winner = game.PlayerAddrs[0];
            loser = game.PlayerAddrs[1];
        }
        players[winner].wins += 1;
        players[winner].streak += 1;
        players[winner].proxyAddress = address(0);
        players[loser].losses += 1;
        players[loser].streak = 0;
        players[loser].proxyAddress = address(0);

        // grant rewards
        gameWallet.transfer(winner, address(this), game.wager);
        gameWallet.transferToTreasury(address(this), game.wager);
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

    function getGame(uint id) public view returns (Game memory) {
        return games[id];
    }

    //  SETTERS
    function setMinWalletBal(uint _minWalletBal) public onlyOwner {
        minWalletBal = _minWalletBal;
    }
}
