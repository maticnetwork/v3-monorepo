import * as dotenv from 'dotenv'

import { HardhatUserConfig, task } from 'hardhat/config'
import 'solidity-coverage'
import '@nomiclabs/hardhat-etherscan'
import '@nomiclabs/hardhat-waffle'
import '@typechain/hardhat'
import 'hardhat-gas-reporter'
import './src/type-extensions'
import './tasks'

dotenv.config()

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async(taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners()

  for (const account of accounts) {
    console.log(account.address)
  }
})

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  networks: {
    ropsten: {
      url: process.env.ROPSTEN_URL || '',
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : []
    },
    hardhat: {
      blockGasLimit: 100_000_000,
      gas: 100_000_000,
      allowUnlimitedContractSize: true
    }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: 'USD'
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  },
  paths: {
    sourceTemplates: 'contracts',
    sources: 'contracts-out'
  },
  solidity: {
    version: '0.8.12',
    settings: {
      metadata: {
        bytecodeHash: 'none'
      },
      optimizer: {
        enabled: true,
        runs: 800
      }
    }
  }
}

export default config
