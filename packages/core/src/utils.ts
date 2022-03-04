import solc from 'solc'

const SolidityBinaries = {
  '0.5.17': 'v0.5.17+commit.d19bba13'
}

export async function getPkgJsonDir() {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { dirname } = require('path')
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { constants, promises: { access } } = require('fs')

  for (const path of module.paths) {
    try {
      const prospectivePkgJsonDir = dirname(path)
      await access(path, constants.F_OK)
      return prospectivePkgJsonDir
    } catch (e) { }
  }
}

export function hasValue(value: unknown) {
  return value !== undefined && value !== null
}

export function loadSolcBinary(solidityVerstion: string) {
  return new Promise((resolve, reject) => {
    solc.loadRemoteVersion(SolidityBinaries[solidityVerstion], function(err: unknown, snapshot: unknown) {
      if (err) {
        reject(err)
      } else {
        resolve(snapshot)
      }
    })
  })
}

export const cc = {
  async intendGroup(f: () => Promise<void>, ...labels: string[]) {
    console.group(...labels)
    try {
      await f()
    } finally {
      console.groupEnd()
    }
  },
  logLn(str = '') {
    console.log(`${str}\n`)
  },
  log: console.log
}

export const ZeroAddress = '0x0000000000000000000000000000000000000000'

export function extractParameters(params: string) {
  if (!params) {
    return []
  }
  return params.split(',').map(x => x.trim())
}
