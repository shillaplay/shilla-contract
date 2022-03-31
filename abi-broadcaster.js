const { setDeployed, getDeployed, saveAbiToWeb } = require("./functions");
const path = require("path")
const execSync = require('child_process').execSync;

const copyToSubgraph = (name, p) => {
  saveAbiToWeb(
    path.join(__dirname, p, `abis/${name}.json`), 
    name, 
    abiAll => abiAll
  )

  try {
    execSync(`sed -i -E "s/(address: \")(.+)(\")/address: \\"${getDeployed(name)}\\"/" ${path.join(__dirname, p, `subgraph.yaml`)}`);
    console.log(`${name} address copied to its subgraphs manifests`)
  
  } catch(e) {
    console.log(`${name} address copied to its subgraphs manifests failed with: `, e.message)
  }
}
copyToSubgraph("ShillaGame", "../shilla-subgraph/subgraphs/games")
copyToSubgraph("Shilla", "../shilla-subgraph/subgraphs/shills")
copyToSubgraph("ShillaVault", "../shilla-subgraph/subgraphs/stakes")
/*
saveAbiToWeb(
  path.join(__dirname, "../shilla-subgraph/subgraphs/games/abis/ShillaGame.json"), 
  "ShillaGame", 
  abiAll => abiAll
)
saveAbiToWeb(
  path.join(__dirname, "../shilla-subgraph/subgraphs/shills/abis/Shilla.json"), 
  "Shilla", 
  abiAll => abiAll
)
saveAbiToWeb(
  path.join(__dirname, "../shilla-subgraph/subgraphs/stakes/abis/ShillaVault.json"), 
  "ShillaVault", 
  abiAll => abiAll
)*/


