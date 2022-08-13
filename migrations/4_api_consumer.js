const APIConsumer = artifacts.require("APIConsumer")
const LinkToken = artifacts.require("LinkToken")
const MockOracle = artifacts.require("MockOracle")
const web3 = require("web3")

const { networkConfig } = require("../helper-truffle-config")

module.exports = async function (deployer, network, accounts) {
    let oracle, linkTokenAddress

    if (network == "development") {
        const linkToken = await LinkToken.deployed()
        const mockOracle = await MockOracle.deployed()
        linkTokenAddress = linkToken.address
        oracle = mockOracle.address
    } else {
        linkTokenAddress = networkConfig[network]["linkToken"]
        oracle = networkConfig[network]["oracle"]
    }
    const jobId = web3.utils.toHex(networkConfig[network]["jobId"])
    const fee = networkConfig[network]["fee"]

    await deployer.deploy(APIConsumer, oracle, jobId, fee, linkTokenAddress)
    console.log("API Consumer Deployed!")
}