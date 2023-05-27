const { assert } = require("chai")
const RPS_Game = artifacts.require("RPS_Game")
const SecurityVault = artifacts.require("SecurityVault")
const InitVerifier = artifacts.require("InitVerifier")
const MoveAVerifier = artifacts.require("MoveAVerifier")
const MoveBVerifier = artifacts.require("MoveBVerifier")

// const Web3 = require("web3")
// const web3 = new Web3()

const truffleAssert = require("truffle-assertions")

contract("RPS_Game", function () {
    let accounts, player0, player1, deployer
    let rpsGame, securityVault
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

        // deploy vault
        securityVault = await SecurityVault.new(
            // min deposit 1 ether
            web3.utils.toWei("1", "ether"),
            { from: deployer }
        )
        // deploy Game
        rpsGame = await RPS_Game.new(securityVault.address, { from: deployer })
    })

    it("deposit security amount and withdraw", async () => {
        // deposit 1 ether
        const amount = web3.utils.toWei("1", "ether")
        await securityVault.deposit({ from: player0.address, value: amount })
        // deposit < 1 ether should fail
        await truffleAssert.reverts(
            securityVault.deposit({ from: player1.address, value: 1 }),
            "Deposit amount is incorrect"
        )

        let balance = await securityVault.deposits(player0.address)
        assert.equal(balance, amount)

        // withdraw
        await securityVault.withdraw({ from: player0.address })
        balance = await securityVault.deposits(player0.address)
        assert.equal(balance, 0)
    })

    it("players can start a game", async () => {
        // deposit 1 ether
        const amount = web3.utils.toWei("1", "ether")
        await securityVault.deposit({ from: player0.address, value: amount })
        await securityVault.deposit({ from: player1.address, value: amount })

        let validUntil = (await web3.eth.getBlock("latest")).timestamp + 1000
        let wager = 0
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
        // assert.equal(game.PlayerAddrs[0], player0.address)
        // assert.equal(game.PlayerProxyAddrs[0], player0.address)
        // assert.equal(game.PlayerAddrs[1], player1.address)
        // assert.equal(game.PlayerProxyAddrs[1], player1.address)
        assert.equal(game.finalizedAt, 0)
        assert.equal(game.wager, wager)
    })
})
