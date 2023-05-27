const { assert } = require("chai")
const GameWallet = artifacts.require("GameWallet")
const TestToken = artifacts.require("TestToken")

const truffleAssert = require("truffle-assertions")

contract("GameWallet", function () {
    let deployer, userA, userB
    let gameWallet
    beforeEach(async () => {
        let accounts = await web3.eth.getAccounts()
        deployer = accounts[0]
        userA = accounts[1]
        userB = accounts[2]
        testToken = await TestToken.new({ from: deployer })
        await testToken.mint({ from: userA })
        await testToken.mint({ from: userB })
        gameWallet = await GameWallet.new(testToken.address, { from: deployer })
        // approve gameWallet
        await testToken.approve(gameWallet.address, web3.utils.toWei("100", "ether"), {
            from: userA,
        })
        await testToken.approve(gameWallet.address, web3.utils.toWei("100", "ether"), {
            from: userB,
        })
    })

    it("deposit amount and withdraw", async () => {
        // deposit 1 ether
        const amt = web3.utils.toWei("1", "ether")
        await gameWallet.deposit(amt, { from: userA })

        let balance = await gameWallet.deposits(userA)
        assert.equal(balance, amt)

        // withdraw should revert
        await truffleAssert.reverts(gameWallet.withdraw({ from: userA }), "Not possible")

        // transfer should not work
        await truffleAssert.reverts(
            gameWallet.transfer(userB, userA, web3.utils.toWei("1", "ether"), { from: userA })
        )
        await truffleAssert.reverts(
            gameWallet.transfer(userB, userA, web3.utils.toWei("1", "ether"), { from: userB })
        )
    })

    it("ORGANIZER should be able to slash/transfer", async () => {
        const amt = web3.utils.toWei("10", "ether")
        await gameWallet.deposit(amt, { from: userA })
        await gameWallet.deposit(amt, { from: userB })
        // deployer grants ORGANIZER role to itself
        await gameWallet.grantRole(await gameWallet.ORGANISER_ROLE(), deployer, {
            from: deployer,
        })
        // transfer 1 ether from userA to userB
        await gameWallet.transfer(userA, userB, web3.utils.toWei("1", "ether"), { from: deployer })

        assert.equal(await gameWallet.deposits(userA), web3.utils.toWei("11", "ether"))
        assert.equal(await gameWallet.deposits(userB), web3.utils.toWei("9", "ether"))

        // slash 1 ether from userA
        await gameWallet.slash(userA, web3.utils.toWei("5", "ether"), { from: deployer })
        assert.equal(await gameWallet.deposits(userA), web3.utils.toWei("6", "ether"))
    })
})
