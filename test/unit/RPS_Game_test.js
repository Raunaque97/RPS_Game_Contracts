const { assert } = require("chai")
const RPS_Game = artifacts.require("RPS_Game")
const GameWallet = artifacts.require("GameWallet")
const TestToken = artifacts.require("TestToken")
const InitVerifier = artifacts.require("InitVerifier")
const MoveAVerifier = artifacts.require("MoveAVerifier")
const MoveBVerifier = artifacts.require("MoveBVerifier")

// const Web3 = require("web3")
// const web3 = new Web3()

const truffleAssert = require("truffle-assertions")

contract("RPS_Game", function () {
    let accounts, player0, player1, deployer
    let rpsGame, gameWallet
    beforeEach(async () => {
        accounts = await web3.eth.getAccounts()
        deployer = accounts[0]
        player0 = web3.eth.accounts.create(["x0x"])
        player1 = web3.eth.accounts.create(["x1x"])
        // unlock accounts
        await web3.eth.personal.importRawKey(player0.privateKey, "")
        await web3.eth.personal.unlockAccount(player0.address, "", 10000)
        await web3.eth.personal.importRawKey(player1.privateKey, "")
        await web3.eth.personal.unlockAccount(player1.address, "", 10000)
        // send some ether to player0 and player1
        await web3.eth.sendTransaction({
            from: deployer,
            to: player0.address,
            value: web3.utils.toWei("10", "ether"),
        })
        await web3.eth.sendTransaction({
            from: deployer,
            to: player1.address,
            value: web3.utils.toWei("10", "ether"),
        })

        // console.log("deployer: " + deployer)
        // console.log("player0: " + player0.address)
        // console.log("player1: " + player1.address)

        // deploy contracts
        testToken = await TestToken.new({ from: deployer })
        gameWallet = await GameWallet.new(testToken.address, { from: deployer })
        rpsGame = await RPS_Game.new(gameWallet.address, web3.utils.toWei("1", "ether"), {
            from: deployer,
        })
        // mint TestToken to player0 and player1
        await testToken.mint({ from: player0.address })
        await testToken.mint({ from: player1.address })
        // approve GameWallet to spend TestToken
        await testToken.approve(gameWallet.address, web3.utils.toWei("1", "ether"), {
            from: player0.address,
        })
        await testToken.approve(gameWallet.address, web3.utils.toWei("1", "ether"), {
            from: player1.address,
        })
        // grants ORGANIZER role to rpsGame
        await gameWallet.grantRole(await gameWallet.ORGANISER_ROLE(), rpsGame.address, {
            from: deployer,
        })
    })

    it("players can start a game", async () => {
        // deposit 1 TestToken to GameWallet
        const amount = web3.utils.toWei("1", "ether")
        await gameWallet.deposit(amount, { from: player0.address })
        await gameWallet.deposit(amount, { from: player1.address })

        let validUntil = (await web3.eth.getBlock("latest")).timestamp + 1000
        let wager = 100
        // calc signature
        // refer: keccak256(abi.encodePacked(_player0Addrs, _player0ProxyAddrs, wager, validUntil))
        // https://ethereum.stackexchange.com/a/126147
        const msgHash = web3.utils.soliditySha3(
            web3.utils.encodePacked(
                { value: player0.address, type: "address" },
                { value: player0.address, type: "address" },
                { value: wager, type: "uint256" },
                { value: validUntil, type: "uint256" }
            )
        )
        // console.log("keccak data : ", msgHash)
        const sign = (await web3.eth.accounts.sign(msgHash, player0.privateKey)).signature
        // console.log("signature: ", sign)
        await rpsGame.startGame(
            player0.address,
            player0.address,
            player1.address,
            wager,
            validUntil,
            sign, // signature0
            {
                from: player1.address,
            }
        )

        // check game state
        // check counter is 1
        const counter = await rpsGame.counter()
        assert.equal(counter, 1)

        const game = await rpsGame.getGame(counter)
        console.log("game: ", { game })
        assert.equal(game.PlayerAddrs[0], player0.address)
        assert.equal(game.PlayerProxyAddrs[0], player0.address)
        assert.equal(game.PlayerAddrs[1], player1.address)
        assert.equal(game.PlayerProxyAddrs[1], player1.address)
        assert.equal(game.finalizedAt, 0)
        assert.equal(game.wager, wager)
    })
})
