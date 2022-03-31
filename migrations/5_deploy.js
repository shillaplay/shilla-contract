const { setDeployed, getDeployed, saveAbiToWeb } = require("../functions");
const path = require("path")

const Shilla = artifacts.require("Shilla");
const ShillaBadge = artifacts.require("ShillaBadge");

module.exports = async (deployer) => {
  await deployer.deploy(ShillaBadge, getDeployed("Shilla"))
  console.log("ShillaBadge.deploy", ShillaBadge.address)
  var address = ShillaBadge.address
  //save the token address into file for the next deployed contract to use for deployment
  setDeployed("ShillaBadge", address)
  
  saveAbiToWeb(path.join(__dirname, "../../shilla/src/abis/ShillaBadge.json"), "ShillaBadge", abiAll => {
    var abiShort = {address: address, ...abiAll}
    return abiShort
  })

  const DECIMALS = "000000000"
  const instance = await ShillaBadge.deployed()
  await instance.addBadgeLevel(100, `100000${DECIMALS}`);
  await instance.addBadgeLevel(400, `10000${DECIMALS}`);
  await instance.addBadgeLevel(600, `1000${DECIMALS}`);
  console.log("ShillaBadge.add.done")
}