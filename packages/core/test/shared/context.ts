import { Fixture } from 'ethereum-waffle'
import { Signer, Wallet } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { ChainConfig, ERC20Token, StakingService, ValidatorSlot } from 'typechain-types'

export interface Contracts {
    stakingService: StakingService;
    stakingToken: ERC20Token;
    validatorSlot: ValidatorSlot;
    config: ChainConfig;
}

export interface Signers {
    governance: Signer;

    delegators: Signer[];
    validators: Wallet[];
}

declare module 'mocha' {
    interface Context {
        contracts: Contracts;
        loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
        signers: Signers;
    }
}

export function runTestWithContext(description: string, hooks: () => void) {
  describe(description, function() {
    before(async function() {
      this.signers = {} as Signers
      this.contracts = {} as Contracts

      const signers = await ethers.getSigners()

      this.signers.governance = signers[0]
      this.signers.delegators = signers.slice(1)
      this.signers.validators = signers.slice(1) as Signer[] as Wallet[]

      this.loadFixture = waffle.createFixtureLoader(signers as Signer[] as Wallet[])
    })

    hooks()
  })
}
