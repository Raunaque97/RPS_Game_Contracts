const RPS_Game = artifacts.require("RPS_Game")
const SecurityVault = artifacts.require("SecurityVault")
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

    const securityVault = await deployer.deploy(SecurityVault, 10)
    console.log("Security Vault Deployed at address: ", securityVault.address)

    const rpsGame = await deployer.deploy(RPS_Game, securityVault.address)
    console.log("RPS_Game Deployed! at address: ", rpsGame.address)
}
