import { Signer } from 'ethers'
import { waffle, artifacts, ethers } from 'hardhat'
import { Delegation, DelegationBeacon, DelegationProxyCreator, ERC20Token, StakingLogger, StakingService, ValidatorSlot } from 'typechain-types'
import { deployProxy } from './deployers'

const { deployContract } = waffle

type StakingServiceFixture = {
    token: ERC20Token;
    stakingService: StakingService;
    logger: StakingLogger;
    validatorSlot: ValidatorSlot;
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

  await logger.connect(governance).initialize(stakingService.address)
  await stakingService.connect(governance).initialize(
    delegationProxyCreator.address,
    logger.address,
    validatorSlot.address,
    token.address
  )

  await validatorSlot.transferOwnership(stakingService.address)

  const allowance = ethers.utils.parseEther('100000')
  for (const delegator of signers) {
    await token.mint(await delegator.getAddress(), allowance)
    await token.increaseAllowance(stakingService.address, allowance)
  }

  return {
    validatorSlot,
    logger,
    token,
    stakingService: stakingService.connect(governance)
  }
}