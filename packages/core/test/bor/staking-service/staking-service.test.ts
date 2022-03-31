import { ethers } from 'hardhat'
import { runTestWithContext } from '../../shared/context'
import { stakingServiceFixture } from '../../shared/fixtures'
import { shouldBehaveLikeStaking } from './behaviors/staking.behavior'

runTestWithContext('StakingService', function() {
  beforeEach(async function() {
    const { stakingService, token, validatorSlot } = await this.loadFixture(stakingServiceFixture)

    this.contracts.stakingService = stakingService
    this.contracts.stakingToken = token
    this.contracts.validatorSlot = validatorSlot
  })

  shouldBehaveLikeStaking()
})
