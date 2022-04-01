import { Signer } from 'ethers'
import { waffle, artifacts, ethers } from 'hardhat'
import { ChainConfig, Delegation, DelegationBeacon, DelegationProxyCreator, ERC20Token, StakingLogger, StakingService, ValidatorSlot } from 'typechain-types'
import { deployProxy } from './deployers'

const { deployContract } = waffle

type StakingServiceFixture = {
    token: ERC20Token;
    stakingService: StakingService;
    logger: StakingLogger;
    validatorSlot: ValidatorSlot;
    config: ChainConfig;
}

export async function stakingServiceFixture(signers: Signer[]): Promise<StakingServiceFixture> {
  const governance = signers[0]
  const deployer = signers[9]

  const delegation = <Delegation> await deployContract(deployer, artifacts.readArtifactSync('Delegation'))
  const delegationBeacon = <DelegationBeacon> await deployContract(deployer, artifacts.readArtifactSync('DelegationBeacon'), [delegation.address])
  const delegationProxyCreator = <DelegationProxyCreator> await deployContract(deployer, artifacts.readArtifactSync('DelegationProxyCreator'), [delegationBeacon.address])

  const token = <ERC20Token> await deployContract(deployer, artifacts.readArtifactSync('ERC20Token'))
  const validatorSlot = <ValidatorSlot> await deployContract(deployer, artifacts.readArtifactSync('ValidatorSlot'))
  const stakingService = <StakingService> await deployProxy(deployer, 'StakingService')
  const logger = <StakingLogger> await deployProxy(deployer, 'StakingLogger')
  const config = <ChainConfig> await deployProxy(deployer, 'ChainConfig')

  await config.connect(governance).initialize()
  await logger.connect(governance).initialize(stakingService.address)
  await stakingService.connect(governance).initialize(
    delegationProxyCreator.address,
    logger.address,
    validatorSlot.address,
    token.address,
    config.address
  )

  await validatorSlot.transferOwnership(stakingService.address)

  const allowance = ethers.utils.parseEther('100000')
  for (const delegator of signers) {
    await token.mint(await delegator.getAddress(), allowance)
    await token.connect(delegator).increaseAllowance(stakingService.address, allowance)
  }

  return {
    validatorSlot: validatorSlot.connect(governance),
    logger: logger.connect(governance),
    token: token.connect(governance),
    stakingService: stakingService.connect(governance),
    config: config.connect(governance)
  }
}
