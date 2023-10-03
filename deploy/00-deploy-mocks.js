const { network } = require("hardhat")
const { developmentChains } = require("../helper-hardhat-config")
require("dotenv").config()
const BASE_FEE = ethers.utils.parseEther("0.25") //o.25 is the premium it costs 0.25 link
const GAS_PRICE_LINK = 1e9
module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    const args = [BASE_FEE, GAS_PRICE_LINK]
    if (developmentChains.includes(network.name)) {
        console.log("Local networks detected! Deploying mocks.....")
        //deploy a mock vrfcoordinator...
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        })
        console.log("Mock deployed!..")
        log("_____________MOCK________________")
    }
}
module.exports.tags = ["all", "mocks"]
