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

  const shilla = await Shilla.deployed()
  await shilla.transfer(`0x7626cE263e2b627DCc40121da83706C85bD9C830`, `10000${DECIMALS}`)
  await shilla.transfer(`0xb6bc660BA9bE2b2e4C944d9f23036a686c83E1Ac`, `1000${DECIMALS}`)

  await instance.mint(1, `0x15752C16611d3312604Ef63324f754c18F1C2656`);
  await instance.mint(2, `0x7626cE263e2b627DCc40121da83706C85bD9C830`);
  await instance.mint(3, `0xb6bc660BA9bE2b2e4C944d9f23036a686c83E1Ac`);
  console.log("ShillaBadge.add.done")
}