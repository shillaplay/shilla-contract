/**
 * Use this file to configure your truffle project. It's seeded with some
 * common settings for different networks and features like migrations,
 * compilation and testing. Uncomment the ones you need or modify
 * them to suit your project as necessary.
 *
 * More information about configuration can be found at:
 *
 * trufflesuite.com/docs/advanced/configuration
 *
 * To deploy via Infura you'll need a wallet provider (like @truffle/hdwallet-provider)
 * to sign your transactions before they're sent to a remote public node. Infura accounts
 * are available for free at: infura.io/register.
 *
 * You'll also need a mnemonic - the twelve word phrase the wallet uses to generate
 * public/private key pairs. If you're publishing your code to GitHub make sure you load this
 * phrase from a file you've .gitignored so it doesn't accidentally become public.
 *
 */

 const dotenv = require('dotenv')
 const result = dotenv.config({ path: '../_env/safetube.env' })
 if(result.error) {
     console.log("ENV:E", result.error)
 
 }
  
 const HDWalletProvider = require('@truffle/hdwallet-provider');
 // const infuraKey = "fj4jll3k.....";
 //
 
 //const fs = require('fs');
 //mnemonic = fs.readFileSync(".secret").toString().trim();
 mnemonic = process.env.mnemonic.trim()
 
 module.exports = {
   /**
    * Networks define how you connect to your ethereum client and let you set the
    * defaults web3 uses to send transactions. If you don't specify one truffle
    * will spin up a development blockchain for you on port 9545 when you
    * run `develop` or `test`. You can ask a truffle command to use a specific
    * network from the command line, e.g
    *
    * $ truffle test --network <network-name>
    */
 
   networks: {
      development: {
        host: "144.91.116.74",     // Localhost (default: none)
        port: 8545,            // Standard BSC port (default: none)
        network_id: "*",       // Any network (default: none)
        from: "0x15752C16611d3312604Ef63324f754c18F1C2656",
        timeoutBlocks: 200,
        skipDryRun: true,
        gas: 20000000,//default: 6721975
        gasPrice: 20000000000//default: 20000000000 (20 Gwei)
     },
     testnet: {
      networkCheckTimeout: 999999,
      provider: () => new HDWalletProvider(mnemonic, `wss://data-seed-prebsc-2-s2.binance.org:8545`/*`wss://data-seed-prebsc-1-s3.binance.org:8545` */),
      network_id: 97,
      chainId: 97,
      confirmations: 10,
      networkCheckTimeoutnetworkCheckTimeout: 10000,
      timeoutBlocks: 200,
      skipDryRun: true,
      gas: 20000000,//default: 6721975
      gasPrice: 50000000000//default: 20000000000 (20 Gwei)
     },
     bsc: {
       provider: () => new HDWalletProvider(mnemonic, `https://bsc-dataseed1.binance.org`),
       network_id: 56,
       chainId: 56,
       confirmations: 10,
       timeoutBlocks: 200,
       skipDryRun: true
     },
   },
 
   // Set default mocha options here, use special reporters etc.
   mocha: {
     // timeout: 100000
   },
 
   // Configure your compilers
   compilers: {
     solc: {
       version: "^0.8.0", // A version or constraint - Ex. "^0.5.0"
       settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
     }
   },
   plugins: [
     'truffle-plugin-verify', 'truffle-contract-size'
   ],
   api_keys: {
    bscscan: process.env.BSC_API_KEY
   },
 
   // Truffle DB is currently disabled by default; to enable it, change enabled: false to enabled: true
   //
   // Note: if you migrated your contracts prior to enabling this field in your Truffle project and want
   // those previously migrated contracts available in the .db directory, you will need to run the following:
   // $ truffle migrate --reset --compile-all
 
   db: {
     enabled: false
   }
 };