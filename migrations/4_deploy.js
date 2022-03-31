const { setDeployed, getDeployed, saveAbiToWeb } = require("../functions");
const path = require("path")

const Shilla = artifacts.require("Shilla");
const ShillaVault = artifacts.require("ShillaVault");
const ShillaGame = artifacts.require("ShillaGame");
const ShillaGameLib = artifacts.require("ShillaGameLib");

async function doDeploy(deployer, network) {
  await deployer.deploy(ShillaGameLib)
  await deployer.link(ShillaGameLib, ShillaGame)
}

module.exports = async (deployer, network) => {
  await doDeploy(deployer, network)
  await deployer.deploy(ShillaGame, getDeployed("Shilla"), getDeployed("ShillaVault"), 9)
  console.log("ShillaGame.deploy", ShillaGame.address)
  var address = ShillaGame.address
  //save the token address into file for the next deployed contract to use for deployment
  setDeployed("ShillaGame", address)
  
  saveAbiToWeb(path.join(__dirname, "../../shilla/src/abis/ShillaGame.json"), "ShillaGame", abiAll => {
    var abiShort = {address: address, ...abiAll}
    return abiShort
  })
  Shilla.deployed()
  .then(instance => {
    instance._excludeFromFee(address);
    instance._excludeFromMaxFrom(address);
    instance._excludeFromMaxTo(address);
  })
}