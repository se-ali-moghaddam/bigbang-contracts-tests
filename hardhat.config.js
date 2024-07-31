require('@nomicfoundation/hardhat-toolbox');
require('@nomicfoundation/hardhat-web3-v4');
require("@nomiclabs/hardhat-solhint");

const BNB_TESTNET_URL = 'https://go.getblock.io/a3a4ef15f64942ccac82ff568ed2edb7';
const BNB_ACCOUNT_PRIVATE_KEY = '0f32ac67cea43b3a89e8bf1c36fe035b2931c36ea1dd41de8bf42f7f5c1e7e18';
const BSCSCAN_API_KEY = '1DIYEA966GPR43UP3E7A9YKD7QGTT5D4KI';

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  allowUnlimitedContractSize: true,
  networks: {
    bnb_testnet:{
      url: BNB_TESTNET_URL,
      accounts: [BNB_ACCOUNT_PRIVATE_KEY]
    }
  },
  etherscan:{
    apiKey: BSCSCAN_API_KEY
  }
}
