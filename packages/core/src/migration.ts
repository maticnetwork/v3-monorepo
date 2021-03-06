import chalk from 'chalk'
import { ReleaseRegistry, cc } from './index'

import { Artifacts } from 'hardhat/types'
import { extractParameters } from './utils'
import { ethers } from 'ethers'

export async function deployProxyImplementation(artifacts: Artifacts, contractName: string, network: string, from: string) {
  // const artifact = artifacts.require(contractName) as any
  // const instance = await artifact.new({ from })
  // const deployedAddress = instance.address

  // const registry = new ReleaseRegistry(network)
  // await registry.load()

  // cc.logLn()
  // await cc.intendGroup(async () => {
  //   cc.logLn(`Deployed ${contractName} at ${deployedAddress}`)

  //   printProxyUpdateCommand(registry.getAddress(`${contractName}Proxy`), registry.getAddress(contractName))
  //   cc.logLn()
  // }, 'Deployment result:')

  // return { address: deployedAddress }
}

export async function deployPredicate(artifacts: Artifacts, network: string, from: string, params: string) {
  // const [contractName, ...ctorArgs] = extractParameters(params)
  // const artifact = artifacts.require(contractName) as any
  // const instance = await artifact.new(ctorArgs, { from })
  // const deployedAddress = instance.address

  // const registry = new ReleaseRegistry(network)
  // await registry.load()

  // cc.logLn()
  // await cc.intendGroup(async () => {
  //   cc.logLn(`Deployed ${contractName} at ${deployedAddress}`)

  //   const registryContract = await (artifacts.require('Registry') as RegistryContract).at(registry.getAddress('Registry'))
  //   const calldata = registryContract.contract.methods.updateContractMap(ethers.utils.keccak256(contractName), deployedAddress).encodeABI()
  //   printGovernanceUpdateCommand(registry.getAddress('GovernanceProxy'), registry.getAddress('Registry'), calldata)
  //   cc.logLn()
  // }, 'Deployment result:')

  // return { address: deployedAddress, args: ctorArgs }
}
