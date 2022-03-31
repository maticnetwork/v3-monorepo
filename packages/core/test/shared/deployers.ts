import { artifacts, waffle } from 'hardhat'
import { Contract, Signer } from 'ethers'

const { deployContract } = waffle

export async function deployProxy(deployer: Signer, artifactName: string): Promise<Contract> {
  const implementationArtifact = artifacts.readArtifactSync(artifactName)
  const implementation = await deployContract(deployer, implementationArtifact)
  const proxy = await deployContract(deployer, artifacts.readArtifactSync(`${artifactName}Proxy`), [
    implementation.address, await deployer.getAddress(), '0x'
  ])
  return new Contract(proxy.address, implementationArtifact.abi, deployer)
}
