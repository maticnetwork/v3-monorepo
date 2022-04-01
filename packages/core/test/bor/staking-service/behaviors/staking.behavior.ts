import { expect } from 'chai'
import { BigNumber } from 'ethers'
import { ethers, network } from 'hardhat'
import { beforeEach, Context } from 'mocha'
import { SYSTEM_ADDRESS } from '../../../shared/constants'

function newWallet() {
  return new ethers.Wallet(ethers.Wallet.createRandom())
}

const DEFAULT_SINGLE_VALIDATOR_REWARD = BigNumber.from(ethers.utils.parseEther('1'))
const DEFAULT_ALL_VALIDATORS_REWARD = BigNumber.from(ethers.utils.parseEther('1'))
const DEFAULT_SIGNER = newWallet()

export function shouldBehaveLikeStaking() {
  async function _claimSlot(this: Context, validatorIndex = 0, wallet = DEFAULT_SIGNER) {
    return await this.contracts.stakingService.connect(this.signers.validators[validatorIndex]).claimValidatorSlot(
      await this.signers.validators[validatorIndex].getAddress(),
      ethers.utils.parseEther('1'),
            `0x${wallet.publicKey.replace('0x04', '')}`
    )
  }

  beforeEach(async function() {
    await this.contracts.config.setCheckpointReward(DEFAULT_ALL_VALIDATORS_REWARD)
  })

  describe('claimValidatorSlot()', function() {
    describe('when validator acquire a free slot', function() {
      it('should claim free slot', _claimSlot)

      it('should mint slot NFT', async function() {
        await expect(_claimSlot.call(this))
          .to.emit(this.contracts.validatorSlot, 'Transfer')
          .withArgs(ethers.constants.AddressZero, await this.signers.validators[0].getAddress(), '1')
      })

      it('should have correct total locked tokens', async function() {
        await _claimSlot.call(this)

        expect(await this.contracts.stakingService.totalLockedTokens(1)).to.be.equal(
          BigNumber.from(ethers.utils.parseEther('1'))
        )
      })
    })

    describe('when contract locked', function() {
      it('should revert', async function() {
        await this.contracts.stakingService.lock()
        await expect(_claimSlot.call(this)).to.be.revertedWith('locked')
      })
    })
  })

  describe('stake()', function() {
    beforeEach(async function() {
      await _claimSlot.call(this)

      await network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [SYSTEM_ADDRESS]
      })

      await this.signers.governance.sendTransaction({ value: ethers.utils.parseEther('10'), to: SYSTEM_ADDRESS })
    })

    describe('when non-validator stakes', function() {
      it('should revert', async function() {
        await expect(this.contracts.stakingService.connect(this.signers.validators[1]).stake(
          '1',
          '1000',
          false
        ))
          .to.be.revertedWith('not validator')
      })
    })

    describe('when validator stakes to a slot it doesn\'t own', function() {
      it('should revert', async function() {
        await _claimSlot.call(this, 1, newWallet())
        await expect(this.contracts.stakingService.connect(this.signers.validators[1]).stake(
          '1',
          '1000',
          false
        ))
          .to.be.revertedWith('not validator')
      })
    })

    describe('when validator stakes towards his slot', function() {
      describe('without rewards', function() {
        it('should stake', async function() {
          await this.contracts.stakingService.connect(this.signers.validators[0]).stake(
            '1',
            '1000',
            false
          )
        })
      })

      describe('stake only rewards', function() {
        async function _stakeOnlyRewards(this: Context) {
          return this.contracts.stakingService.connect(this.signers.validators[0]).stake(
            '1',
            '0',
            true
          )
        }

        beforeEach(async function() {
          const signer = await ethers.getSigner(SYSTEM_ADDRESS)

          // after staking, reward only accumulated at the next epoch
          // thus skip 1 epoch + 1 more epoch to allow accumulation of rewards
          await this.contracts.stakingService.distributeRewardToAll([])
          await this.contracts.stakingService.distributeRewardToAll([])
          await this.contracts.stakingService.connect(signer).distributeReward(DEFAULT_SIGNER.address, DEFAULT_SINGLE_VALIDATOR_REWARD)
        })

        it('should stake', async function() {
          await _stakeOnlyRewards.call(this)
        })

        it('should have correct current total locked tokens', async function() {
          await _stakeOnlyRewards.call(this)

          const epoch = await this.contracts.stakingService.epoch()
          expect(await this.contracts.stakingService.totalLockedTokens(epoch)).to.be.equal(
            BigNumber.from(ethers.utils.parseEther('1'))
          )
        })

        it('should have correct future total locked tokens', async function() {
          await _stakeOnlyRewards.call(this)

          const epoch = await this.contracts.stakingService.epoch()
          expect(await this.contracts.stakingService.totalLockedTokens(epoch.add(1))).to.be.equal(
            BigNumber.from(ethers.utils.parseEther('1')).add(DEFAULT_ALL_VALIDATORS_REWARD).add(DEFAULT_SINGLE_VALIDATOR_REWARD)
          )
        })

        it('should have correct validator locked tokens', async function() {
          const validatorData = await this.contracts.stakingService.validators(1)
          const lockedTokens = await this.contracts.stakingService.validatorTokens(1, validatorData.lastStakeEpoch)
          expect(lockedTokens).to.be.equal(
            BigNumber.from(ethers.utils.parseEther('1'))
              .add(DEFAULT_ALL_VALIDATORS_REWARD)
              .add(DEFAULT_SINGLE_VALIDATOR_REWARD)
          )
        })
      })
    })
  })
}
