
const { BigNumber } = require("@ethersproject/bignumber");
//ForsageBUSD: https://bscscan.com/address/0x5acc84a3e955bdd76467d3348077d003f00ffb97#code

//BabyDogeRouter: 0x10ED43C718714eb63d5aA57B78B54704E256024E
//MainetPancackeSwapRouter: 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F
//TestnetPancackeSwapRouter: 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
const swapRouterAddress = "0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F"

//MainetBUSD: 0xe9e7cea3dedca5984780bafc599bd69add087d56
//TestnetBUSD: 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7
const busdAddress = "0xe9e7cea3dedca5984780bafc599bd69add087d56";

//MainetBUSD/BNB: 0x87Ea38c9F24264Ec1Fff41B04ec94a97Caf99941
//TestnetBUSD/ETH: 0x5ea7D6A33D3655F661C298ac8086708148883c34
const busdBNBPriceFeedAddress = "0x87Ea38c9F24264Ec1Fff41B04ec94a97Caf99941";

const tokenDecimals = 9;
const BNB_DECIMALS = 18
const BUSD_DECIMALS = 18

const IS_PRODUCTION = false;

const BIG_TEN = BigNumber.from(10)
const powDecimal = decimal => {
    return BIG_TEN.pow(BigNumber.from(decimal))
}


const initialTokenDistributedPerSlot = 
BigNumber.from(
    150//150000 * Math.pow(10, tokenDecimals)
)
.mul(
    powDecimal(tokenDecimals)
).toString()

const tokenPerBNBBig = BigNumber.from(
    140
)
.mul(
    powDecimal(12)
)//140 trillion
.mul(
    powDecimal(tokenDecimals)
)

const minBNBBig = BigNumber.from(
    1,//0.01 * Math.pow(10, 18)
)
.mul(
    powDecimal(BNB_DECIMALS - 2)// -1 => 0., -2 => 0.0
)
const maxBNBBig = BigNumber.from(
    10,//200 * Math.pow(10, 18)
)
.mul(
    powDecimal(BNB_DECIMALS)
)
//console.log(maxBNBBig, minBNBBig.toString())

const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000"

module.exports = {
    IS_PRODUCTION, ADDRESS_ZERO,
    swapRouterAddress, busdAddress, busdBNBPriceFeedAddress, initialTokenDistributedPerSlot, 
    tokenDecimals, powDecimal, tokenPerBNBBig, minBNBBig, maxBNBBig, BNB_DECIMALS, BUSD_DECIMALS
}

/**
 * Test pancaceswap home: https://bsc.kiemtienonline360.com/
 * Test pancaseswap interface: https://pancake.kiemtienonline360.com/#/swap
 */
