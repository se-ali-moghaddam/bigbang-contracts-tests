const { buildModule } = require('@nomicfoundation/hardhat-ignition/modules');
const { web3 } = require('hardhat');

module.exports = buildModule('BigBang_LendingServiceModule', m => {
    const { networkCoinPriceFeed, ownerFeePercent, voteFee, lendingLimitationPercent, lowestPrice, highestPrice, repaymentPeriod, ownerShare }
        = {
        networkCoinPriceFeed: '0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada',
        ownerFeePercent: 38,
        voteFee: web3.utils.toWei(1, 'ether'),
        lendingLimitationPercent: 90,
        lowestPrice: web3.utils.toWei(800, 'ether'),
        highestPrice: web3.utils.toWei(1000, 'ether'),
        repaymentPeriod: 30,
        ownerShare: web3.utils.toWei(1, 'ether')
    };

    const bigbangLendingSystem = m.contract('BigBang_LendingService',
        [
            networkCoinPriceFeed,
            ownerFeePercent,
            voteFee,
            lendingLimitationPercent,
            lowestPrice,
            highestPrice,
            repaymentPeriod,
            ownerShare
        ]);

    return {
        bigbangLendingSystem
    };
});