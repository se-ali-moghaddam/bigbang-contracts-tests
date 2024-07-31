const { Web3 } = require('web3');
const artifacts = require('../artifacts/contracts/BigBang_LendingService.sol/BigBang_LendingService.json');

async function main() {
    const web3 = new Web3('https://data-seed-prebsc-1-s1.binance.org:8545/');
    const privateKey = '0x0f32ac67cea43b3a89e8bf1c36fe035b2931c36ea1dd41de8bf42f7f5c1e7e18';

    const deployer = web3.eth.accounts.privateKeyToAccount(privateKey);

    const bigbangLendingSystemContract = new web3.eth.Contract(artifacts.abi);
    const rawContract = bigbangLendingSystemContract.deploy({
        data: artifacts.bytecode,
        arguments: [
            '0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada', // networkCoinPriceFeed
            38, // ownerFeePercent
            web3.utils.toWei('1', 'ether'), // voteFee
            90, // lendingLimitationPercent
            web3.utils.toWei('800', 'ether'), // lowestPrice
            web3.utils.toWei('1000', 'ether'), // highestPrice
            30, // repaymentPeriod
            web3.utils.toWei('1', 'ether') // ownerShare
        ]
    });

    const gas = await rawContract.estimateGas({from: deployer.address});
    const gasPrice = await web3.eth.getGasPrice();

    const tx = {
        from: deployer.address,
        data: rawContract.encodeABI(),
        gas,
        gasPrice
    };

    const signedTx = web3.eth.accounts.signTransaction(tx, privateKey);

    web3.eth.sendSignedTransaction((await signedTx).rawTransaction)
    .on('receipt', receipt => {
        console.log('Contract address : ' + receipt.contractAddress);
    })
    .on('error', err => {
        console.log('Error deploying contract : ' + err);
    });
}

main().catch(err => {
    console.error(err);
    process.exitCode = 1;
});
