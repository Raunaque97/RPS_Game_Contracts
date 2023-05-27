const RPS_Game = artifacts.require("RPS_Game")
const GameWallet = artifacts.require("GameWallet")
const InitVerifier = artifacts.require("InitVerifier")
const MoveAVerifier = artifacts.require("MoveAVerifier")
const MoveBVerifier = artifacts.require("MoveBVerifier")

module.exports = async function (deployer, network, accounts) {
    console.log("accounts: ", accounts[0])
    await deployer.deploy(InitVerifier)
    await deployer.deploy(MoveAVerifier)
    await deployer.deploy(MoveBVerifier)

    // https://ethereum.stackexchange.com/questions/39372/you-must-deploy-and-link-the-following-libraries-before-you-can-deploy-a-new-ver
    await deployer.link(InitVerifier, RPS_Game)
    await deployer.link(MoveAVerifier, RPS_Game)
    await deployer.link(MoveBVerifier, RPS_Game)

    const erc20ContractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3" //mock

    const gameWallet = await deployer.deploy(GameWallet, erc20ContractAddress)
    console.log("gameWallet Deployed at address: ", gameWallet.address)

    const rpsGame = await deployer.deploy(RPS_Game, gameWallet.address, (1e18).toString())
    console.log("RPS_Game Deployed! at address: ", rpsGame.address)
}
