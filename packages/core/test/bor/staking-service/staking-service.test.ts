import { ethers } from 'hardhat'
import { runTestWithContext } from '../../shared/context'
import { stakingServiceFixture } from '../../shared/fixtures'
import { shouldBehaveLikeStaking } from './behaviors/staking.behavior'

runTestWithContext('StakingService', function() {
  beforeEach(async function() {
    const { stakingService, token, validatorSlot, config } = await this.loadFixture(stakingServiceFixture)

    this.contracts.stakingService = stakingService
    this.contracts.stakingToken = token
    this.contracts.validatorSlot = validatorSlot
    this.contracts.config = config
  })

  shouldBehaveLikeStaking()
})
