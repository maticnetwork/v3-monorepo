import hre from 'hardhat'
import { MockContract } from 'ethereum-waffle'
import type { Artifact } from 'hardhat/types'
import { Signer } from 'ethers'

const { deployMockContract } = hre.waffle

export async function deployMockERC20Token(deployer: Signer): Promise<MockContract> {
  const erc20Atifact: Artifact = await hre.artifacts.readArtifact('IERC20')
  return deployMockContract(deployer, erc20Atifact.abi)
}
