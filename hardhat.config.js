/**
 * @type import('hardhat/config').HardhatUserConfig
 */
// module.exports = {
//   solidity: "0.8.7",
// };

require('@openzeppelin/hardhat-upgrades');

//0xE0b5908dB318F30589066CBBb21c23d5374Dd030
const PRIVATE_KEY = "0xa085a3d9994091986cf42b749d266c1d3449f92bc077c49e320e31aeab63e1c5";

module.exports = {
  solidity: "0.8.7",
  networks: {
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/2820b69f6e3a4af3817000efafbc0667`,
      accounts: [`${PRIVATE_KEY}`]
    },
    bsctest: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545/`,
      accounts: [`${PRIVATE_KEY}`]
      // gas: 2100000,
      // gaslimit: 300000000

    }
  }
};