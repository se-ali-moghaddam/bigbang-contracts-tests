const chai = require('chai');
const { Web3 } = require('web3');
const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');
const artifacts = require('../artifacts/contracts/BigBang_LendingService.sol/BigBang_LendingService.json');

(async () => {
    const chaiAsPromised = await import('chai-as-promised');
    chai.use(chaiAsPromised.default);
})();

const { expect } = chai;

describe('BigBang_LendingService', () => {
    const deployBigbangLendingServiceFixture = async function () {
        const web3 = new Web3('https://go.getblock.io/a3a4ef15f64942ccac82ff568ed2edb7');
        const privateKey = '0x0f32ac67cea43b3a89e8bf1c36fe035b2931c36ea1dd41de8bf42f7f5c1e7e18';

        const { deployer, contractAddress, networkCoinPriceFeed, ownerFeePercent, voteFee, lendingLimitationPercent, lowestPrice, highestPrice, repaymentPeriod, ownerShare } = {
            deployer: web3.eth.accounts.privateKeyToAccount(privateKey),
            contractAddress: '0x9eC950a733Eaa92BEbbFE208793a0672cc967b81',
            networkCoinPriceFeed: '0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada',
            ownerFeePercent: 38,
            voteFee: web3.utils.toWei(1, 'ether'),
            lendingLimitationPercent: 90,
            lowestPrice: web3.utils.toWei(800, 'ether'),
            highestPrice: web3.utils.toWei(1000, 'ether'),
            repaymentPeriod: 30,
            ownerShare: web3.utils.toWei(0, 'ether')
        };

        const bigbangLendingSystem = new web3.eth.Contract(artifacts.abi, contractAddress);

        return {
            web3,
            bigbangLendingSystem,
            deployer,
            contractAddress,
            networkCoinPriceFeed,
            ownerFeePercent,
            voteFee,
            lendingLimitationPercent,
            lowestPrice,
            highestPrice,
            repaymentPeriod,
            ownerShare
        };
    }

    describe('Deployment and General Tests', () => {
        it('Should deployment successful', async () => {
            const { bigbangLendingSystem, contractAddress } = await loadFixture(deployBigbangLendingServiceFixture);

            expect(bigbangLendingSystem.options.address).to.equal(contractAddress);
        });

        it('Should set the right networkCoinPriceFeed', async () => {
            const { bigbangLendingSystem, networkCoinPriceFeed } = await loadFixture(deployBigbangLendingServiceFixture);

            expect(await bigbangLendingSystem.methods.getNetworkCoinPriceFeed().call()).to.equal(networkCoinPriceFeed);
        });

        it('Should set the right voteFee', async () => {
            const { bigbangLendingSystem, voteFee } = await loadFixture(deployBigbangLendingServiceFixture);

            expect(await bigbangLendingSystem.methods.getVoteFee().call()).to.equal(voteFee);
        });

        it('Should to be the lendingLimitationPercent less than 100', async () => {
            const { lendingLimitationPercent } = await loadFixture(deployBigbangLendingServiceFixture);

            expect(lendingLimitationPercent).to.be.lessThan(100);
        });

        it('Should set the right lendingLimitationPercent', async () => {
            const { bigbangLendingSystem, lendingLimitationPercent } = await loadFixture(deployBigbangLendingServiceFixture);

            expect(await bigbangLendingSystem.methods.getLendingLimitation().call()).to.equal(lendingLimitationPercent);
        });

        it('Should to be the ownerFeePercent less than 100', async () => {
            const { ownerFeePercent } = await loadFixture(deployBigbangLendingServiceFixture);

            expect(ownerFeePercent).to.be.lessThan(100);
        });

        it('Should set the right ownerFeePercent', async () => {
            const { bigbangLendingSystem, ownerFeePercent } = await loadFixture(deployBigbangLendingServiceFixture);

            expect(await bigbangLendingSystem.methods.getOwnerFeePercent().call()).to.equal(ownerFeePercent);
        });

        it('Should set the right lowestPrice', async () => {
            const { bigbangLendingSystem, lowestPrice } = await loadFixture(deployBigbangLendingServiceFixture);

            expect(await bigbangLendingSystem.methods.getLowestPrice().call()).to.equal(lowestPrice);
        });

        it('Should set the right highestPrice', async () => {
            const { bigbangLendingSystem, highestPrice } = await loadFixture(deployBigbangLendingServiceFixture);

            expect(await bigbangLendingSystem.methods.getHighestPrice().call()).to.equal(highestPrice);
        });

        it('Should set the right repaymentPeriod', async () => {
            const { bigbangLendingSystem, repaymentPeriod } = await loadFixture(deployBigbangLendingServiceFixture);

            expect(await bigbangLendingSystem.methods.getRepaymentPeriod().call()).to.equal(repaymentPeriod);
        });

        it('Should set the right ownerShare', async () => {
            const { bigbangLendingSystem, deployer, ownerShare } = await loadFixture(deployBigbangLendingServiceFixture);

            bigbangLendingSystem.options.from = deployer.address;
            expect(await bigbangLendingSystem.methods.getOwnerShare().call()).to.equal(ownerShare);
        });

        it('Should reverted for executing by other accounts', async () => {
            const { bigbangLendingSystem } = await loadFixture(deployBigbangLendingServiceFixture);

            expect(await bigbangLendingSystem.methods.getOwnerShare().call()).to.be.revertedWith('You are not owner of contract !');
        });
    });

    describe('Token Functions', () => {
        // it('Should add token successfully', async () => {
        //     const { web3, bigbangLendingSystem, deployer } = await loadFixture(deployBigbangLendingServiceFixture);
        //     const TOKEN_ADDR = '0x157ee9d5c45588b6ea9bdc0dc556b3e5042e2e33';
        //     const PRICE_FEED_ADDR = '0x963D5e7f285Cc84ed566C486c3c1bC911291be38';

        //     // const TOKEN_ADDR = '0x64cea995f784a8a7bd92160d05dec92edbf8f186';
        //     // const PRICE_FEED_ADDR = '0x9Dcf949BCA2F4A8a62350E0065d18902eE87Dca3';

        //     // const TOKEN_ADDR = '0xb98a692f5bb299278ca45a87bb415d9eb0a878a0';
        //     // const PRICE_FEED_ADDR = '0x90c069C4538adAc136E051052E14c1cD799C41B7';

        //     // const TOKEN_ADDR = '0x5bd5451a098ff86cad08afcc44164ff127af5697';
        //     // const PRICE_FEED_ADDR = '0x4046332373C24Aed1dC8bAd489A04E187833B28d';

        //     // const TOKEN_ADDR = '0x4dbf253521e8e8080282c964975f3afb7f87cece';
        //     // const PRICE_FEED_ADDR = '0xEca2605f0BCF2BA5966372C99837b1F182d3D620';

        //     // const TOKEN_ADDR = '0xd66c6b4f0be8ce5b39d52e0fd1344c389929b378';
        //     // const PRICE_FEED_ADDR = '0x143db3CEEfbdfe5631aDD3E50f7614B6ba708BA7';

        //     // const TOKEN_ADDR = '0x735d905451c0B4ac4BBe5Ab323Cf5D6Ad7e3A030';
        //     // const PRICE_FEED_ADDR = '0xE4eE17114774713d2De0eC0f035d4F7665fc025D';

        //     // const TOKEN_ADDR = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56';
        //     // const PRICE_FEED_ADDR = '0x9331b55D9830EF609A2aBCfAc0FBCE050A52fdEa';

        //     try {

        //         const success = await bigbangLendingSystem.methods.addToken(
        //             TOKEN_ADDR,
        //             PRICE_FEED_ADDR
        //         ).call({ from: deployer.address });

        //         expect(success).to.be.true;

        //         const txData = bigbangLendingSystem.methods.addToken(
        //             TOKEN_ADDR,
        //             PRICE_FEED_ADDR
        //         ).encodeABI();

        //         const gasEstimate = await bigbangLendingSystem.methods.addToken(
        //             TOKEN_ADDR,
        //             PRICE_FEED_ADDR
        //         ).estimateGas({ from: deployer.address });

        //         const gasPrice = await web3.eth.getGasPrice();

        //         const tx = {
        //             from: deployer.address,
        //             to: bigbangLendingSystem.options.address,
        //             data: txData,
        //             gas: gasEstimate,
        //             gasPrice: gasPrice
        //         };

        //         const signedTx = await web3.eth.accounts.signTransaction(tx, deployer.privateKey);
        //         const receipt = await web3.eth.sendSignedTransaction(signedTx.rawTransaction);

        //         expect(receipt.status).to.equal(1n);

        //     } catch (error) {
        //         console.error("Error: ", error);
        //         throw error;
        //     }
        // });

        it('Should revert if the token is already added', async () => {
            const { bigbangLendingSystem, deployer, web3 } = await loadFixture(deployBigbangLendingServiceFixture);

            const txData = bigbangLendingSystem.methods.addToken(
                '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56',
                '0x9331b55D9830EF609A2aBCfAc0FBCE050A52fdEa'
            ).encodeABI();

            const gasPrice = await web3.eth.getGasPrice();

            const tx = {
                from: deployer.address,
                to: bigbangLendingSystem.options.address,
                data: txData,
                gas: 3000000,
                gasPrice: gasPrice
            };

            const signedTx = await web3.eth.accounts.signTransaction(tx, deployer.privateKey);

            await expect(
                web3.eth.sendSignedTransaction(signedTx.rawTransaction)
            ).to.be.rejectedWith(Error).then((error) => {
                expect(error.reason).to.equal('execution reverted: This token is already added to the contract.');
            });
        });
    });
});