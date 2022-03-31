const { setDeployed, getDeployed, saveAbiToWeb } = require("../functions");
const path = require("path")

const Shilla = artifacts.require("Shilla");
const ShillaVault = artifacts.require("ShillaVault");

module.exports = function (deployer) {
  deployer.deploy(ShillaVault, getDeployed("Shilla"))
  .then(() => {
    var address = ShillaVault.address
    //save the token address into file for the next deployed contract to use for deployment
    setDeployed("ShillaVault", address)
    
    saveAbiToWeb(path.join(__dirname, "../../shilla/src/abis/ShillaVault.json"), "ShillaVault", abiAll => {
      var abiShort = {address: address, ...abiAll}
      return abiShort
    })
    Shilla.deployed()
    .then(instance => {
      instance._setShillaVault(address);
      instance._excludeFromFee(address);
      instance._excludeFromMaxFrom(address);
      instance._excludeFromMaxTo(address);
    })
  })
}