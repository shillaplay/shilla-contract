const fs = require("fs")

const DEPLOY_PATH = "./deployed.json"

const getDeployJson = () => {
    try {
        return JSON.parse(fs.readFileSync(DEPLOY_PATH))

    } catch {
        return {}
    }
}
const setDeployJson = j => {
    fs.writeFileSync(DEPLOY_PATH, JSON.stringify(j, null, "   "))
}
const setDeployed = (key, value) => {
    var j = getDeployJson()
    j[key] = value
    setDeployJson(j)
}
const getDeployed = key => {
    var j = getDeployJson()
    return j[key]
}

const getAbi = (contractName) => {
    return JSON.parse(fs.readFileSync(`./build/contracts/${contractName}.json`))
}

const readJson = (path) => {
    return JSON.parse(fs.readFileSync(path))
}

const writeJson = (data, path) => {
    fs.writeFileSync(path, JSON.stringify(data, null, "   "))
}

const saveAbiToWeb = (outputPath, contractName, beforeSave) => {
    //get the file
    var j = JSON.parse(fs.readFileSync(`./build/contracts/${contractName}.json`))
    //if(!j) throw exception
    if(beforeSave) {
        j = beforeSave(j)
    }
    fs.writeFileSync(outputPath, JSON.stringify(j, null, "   "))
}

const copyDeployed = outputPath => {
    fs.copyFileSync(DEPLOY_PATH, outputPath)
}

module.exports = {
    setDeployed, getDeployed, saveAbiToWeb, copyDeployed, getAbi, readJson, writeJson
}