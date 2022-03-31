const { setDeployed, getDeployed, saveAbiToWeb } = require("../functions");
const path = require("path")


const Shilla = artifacts.require("Shilla");

module.exports = function (deployer) {
  deployer.deploy(Shilla, "0x000000000000000000000000000000000000dead")
  .then(() => {
    var address = Shilla.address
    //save the token address into file for the next deployed contract to use for deployment
    setDeployed("Shilla", address)
    
    saveAbiToWeb(path.join(__dirname, "../../shilla/src/abis/Shilla.json"), "Shilla", abiAll => {
      var abiShort = {address: address, ...abiAll}
      return abiShort
    })
  })
}