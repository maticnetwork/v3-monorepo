import { expect } from 'chai'
import { ethers } from 'hardhat'
import { Context } from 'mocha'

export function shouldBehaveLikeStaking() {
  const wallet = new ethers.Wallet(ethers.Wallet.createRandom())

  async function _claimSlot(this: Context) {
    return await this.contracts.stakingService.connect(this.signers.validators[0]).claimValidatorSlot(
      await this.signers.validators[0].getAddress(),
      ethers.utils.parseEther('1'),
            `0x${wallet.publicKey.replace('0x04', '')}`
    )
  }

  describe('claimValidatorSlot()', function() {
    describe('when validator acquire a free slot', function() {
      it('should claim free slot', _claimSlot)

      it('should mint slot NFT', async function() {
        await expect(_claimSlot.call(this))
          .to.emit(this.contracts.validatorSlot, 'Transfer')
          .withArgs(ethers.constants.AddressZero, await this.signers.validators[0].getAddress(), '1')
      })
    })

    describe('when contract locked', function() {
      it('should revert', async function() {
        await this.contracts.stakingService.lock()
        await expect(_claimSlot.call(this)).to.be.revertedWith('locked')
      })
    })
  })

  // describe('stake()')
  // describe('unstake()')
}
