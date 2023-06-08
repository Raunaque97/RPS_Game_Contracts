const RPS_Game = artifacts.require("RPS_Game")
const TestToken = artifacts.require("TestToken")
const GameWallet = artifacts.require("GameWallet")
const InitVerifier = artifacts.require("InitVerifier")
const MoveAVerifier = artifacts.require("MoveAVerifier")
const MoveBVerifier = artifacts.require("MoveBVerifier")

module.exports = async function (deployer, network, accounts) {
    console.log("accounts: ", accounts[0])
    // await deployer.deploy(InitVerifier)
    // await deployer.deploy(MoveAVerifier)
    // await deployer.deploy(MoveBVerifier)

    // https://ethereum.stackexchange.com/questions/39372/you-must-deploy-and-link-the-following-libraries-before-you-can-deploy-a-new-ver
    // await deployer.link(InitVerifier, RPS_Game)
    // await deployer.link(MoveAVerifier, RPS_Game)
    // await deployer.link(MoveBVerifier, RPS_Game)

    // const erc20ContractAddress = (await deployer.deploy(TestToken)).address
    const erc20ContractAddress = "0xa69bD215aB75BDf55d4DAB9734c74fea212D7f4C" //mock

    // const gameWallet = await deployer.deploy(GameWallet, erc20ContractAddress)
    // console.log("gameWallet Deployed at address: ", gameWallet.address)
    const gameWalletAddress = "0x39bc12763882A3959E8BFf8A41c24f0381BCBF52"

    const rpsGame = await deployer.deploy(RPS_Game, gameWalletAddress, (1e18).toString())
}
