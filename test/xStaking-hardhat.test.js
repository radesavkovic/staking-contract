const { expect } = require("chai");
const { MockProvider } = require("ethereum-waffle");
const { ethers } = require("hardhat");
const { time } = require('openzeppelin-test-helpers');

require("@nomiclabs/hardhat-ethers");
const assert = require('assert').strict;
const { BigNumber } = require("ethers");

const managerRole = ethers.utils.id("MANAGER_ROLE");

const getNumberFromBN = (bn, d) => {
   return BigNumber.from(bn).div(Math.pow(10, d)).toNumber();
}

function sleep(milliseconds) {
   const date = Date.now();
   let currentDate = null;
   do {
      currentDate = Date.now();
   } while (currentDate - date < milliseconds)
}


contract("xStaking", (accounts) => {
   let token;

   before(async () => {

      [owner, ...accounts] = await ethers.getSigners();
      Erc20 = await hre.ethers.getContractFactory("UvwToken");
      token = await Erc20.deploy();

      await token.deployed();
      console.log("UvwToken deployed to:", token.address);

      xStaking = await hre.ethers.getContractFactory("xStaking");
      xStaked = await xStaking.deploy(token.address);

      await xStaked.deployed();
      console.log("staking deployed to:", xStaked.address);
      const approveAmount = await token.totalSupply()
      await token.approve(xStaked.address, approveAmount)

      await token.connect(accounts[0]).approve(xStaked.address, 100000000000000);
      await token.connect(accounts[1]).approve(xStaked.address, 200000000000000);
      await token.connect(accounts[2]).approve(xStaked.address, 300000000000000);
      await token.connect(accounts[3]).approve(xStaked.address, 400000000000000);
      await token.connect(accounts[4]).approve(xStaked.address, 1000000000000000);
   });

   it('Check Manager Role', async () => {

      expect(await xStaked.hasRole(managerRole, owner.address)).to.equal(true);
      console.log("Owner " + owner.address + " is Manager");
   });

   it('Check Account Balances Before Staking', async () => {
      await token.transfer(accounts[0].address, 1000000000000);
      await token.transfer(accounts[1].address, 2000000000000);
      await token.transfer(accounts[2].address, 3000000000000);
      await token.transfer(accounts[3].address, 4000000000000);
      await token.transfer(accounts[4].address, 10000000000000);
      await token.transfer(accounts[5].address, 6000000000000);

      const balanceOfAccount0 = await token.balanceOf(accounts[0].address);
      const balanceOfAccount1 = await token.balanceOf(accounts[1].address);
      const balanceOfAccount2 = await token.balanceOf(accounts[2].address);
      const balanceOfAccount3 = await token.balanceOf(accounts[3].address);
      const balanceOfAccount4 = await token.balanceOf(accounts[4].address);
      const balanceOfAccount5 = await token.balanceOf(accounts[5].address);

      console.log("accounts 1 : " + balanceOfAccount0);
      console.log("accounts 2 : " + balanceOfAccount1);
      console.log("accounts 3 : " + balanceOfAccount2);
      console.log("accounts 4 : " + balanceOfAccount3);
      console.log("accounts 5 : " + balanceOfAccount4);
      console.log("accounts 6 : " + balanceOfAccount5);

      const ownerBalance = await token.balanceOf(owner.address);
      console.log("Owner balance after transfer : " + ownerBalance);
   });

   it('Check pool info', async () => {
      const periodStaking0 = await xStaked.getPoolConfig(0);
      const periodStaking1 = await xStaked.getPoolConfig(1);
      const periodStaking2 = await xStaked.getPoolConfig(2);
      const periodStaking3 = await xStaked.getPoolConfig(3);

      console.log("pool 0 : " + periodStaking0[0] + " days");
      console.log("pool 1 : " + periodStaking1[0] + " days");
      console.log("pool 2 : " + periodStaking2[0] + " days");
      console.log("pool 3 : " + periodStaking3[0] + " days");
   });

   it('Account0 try to deposit before manager accept deposit', async () => {
      let balanceOfAccount0 = await token.balanceOf(accounts[0].address);

      await expect(xStaked.connect(accounts[0]).stake(balanceOfAccount0)).to.be.reverted;

      balanceOfAccount0 = await token.balanceOf(accounts[0].address);
      expect(balanceOfAccount0).to.equal(1000000000000);
      console.log("balance of account0 : ", balanceOfAccount0.toNumber());
   });

   it('Manager starts acceptDeposit', async () => {
      await xStaked.startStaking(0, 0);

      let poolConfig0 = await xStaked.getPoolConfig(0);
      expect(poolConfig0[0]).to.equal(30);

      await xStaked.startStaking(3, 0);

      let poolConfig3 = await xStaked.getPoolConfig(3);
      expect(poolConfig3[0]).to.equal(360);

      console.log("start deposit : pool_0, " + poolConfig0[0] + " days, " + (await xStaked.getTimeAccepting(0)) + " hours");
      console.log("start deposit : pool_3, " + poolConfig3[0] + " days, " + (await xStaked.getTimeAccepting(3)) + " hours");
   });

   it('Accounts deposit after manager accept deposit', async () => {
      let balanceOfAccount0 = await token.balanceOf(accounts[0].address);
      let balanceOfAccount1 = await token.balanceOf(accounts[1].address);
      let balanceOfAccount2 = await token.balanceOf(accounts[2].address);
      let balanceOfAccount3 = await token.balanceOf(accounts[3].address);
      let balanceOfAccount4 = await token.balanceOf(accounts[4].address);
      console.log("Before deposit");
      console.log("Balance of account0 : ", balanceOfAccount0.toNumber());
      console.log("Balance of account1 : ", balanceOfAccount1.toNumber());
      console.log("Balance of account2 : ", balanceOfAccount2.toNumber());
      console.log("Balance of account3 : ", balanceOfAccount3.toNumber());
      console.log("Balance of account4 : ", balanceOfAccount4.toNumber());

      let balanceOfContract = await token.balanceOf(xStaked.address);
      expect(balanceOfContract).to.equal(0);
      console.log("Balance of contract : ", balanceOfContract.toNumber());

      console.log("About to sleep for 2 hours. Account0 deposits")
      sleep(500)
      await time.increase(2 * 60 * 60);
      await expect(xStaked.connect(accounts[0]).stake(0, balanceOfAccount0));

      console.log("About to sleep for 4 hours. Account1 deposits")
      sleep(500)
      await time.increase(4 * 60 * 60);
      await expect(xStaked.connect(accounts[1]).stake(0, balanceOfAccount1)).to.be.not.reverted;

      console.log("About to sleep for 6 hours. Account2 deposits")
      sleep(500)
      await time.increase(6 * 60 * 60);
      await expect(xStaked.connect(accounts[2]).stake(0, balanceOfAccount2)).to.be.not.reverted;

      console.log("About to sleep for 8 hours. Account3 deposits")
      sleep(500)
      await time.increase(8 * 60 * 60);
      await expect(xStaked.connect(accounts[4]).stake(0, balanceOfAccount4 / 2)).to.be.not.reverted;

      console.log("About to sleep for 3 hours. Account4 deposits")
      sleep(500)
      await time.increase(3 * 60 * 60);
      await expect(xStaked.connect(accounts[3]).stake(0, balanceOfAccount3)).to.be.not.reverted;
      await expect(xStaked.connect(accounts[4]).stake(3, balanceOfAccount4 / 2)).to.be.not.reverted;

      balanceOfAccount0 = await token.balanceOf(accounts[0].address);
      balanceOfAccount1 = await token.balanceOf(accounts[1].address);
      balanceOfAccount2 = await token.balanceOf(accounts[2].address);
      balanceOfAccount3 = await token.balanceOf(accounts[3].address);
      balanceOfAccount4 = await token.balanceOf(accounts[4].address);
      expect(balanceOfAccount0).to.equal(0);
      expect(balanceOfAccount1).to.equal(0);
      expect(balanceOfAccount2).to.equal(0);
      expect(balanceOfAccount3).to.equal(0);
      expect(balanceOfAccount4).to.equal(0);
      console.log("After deposit");
      console.log("Balance of account0 : ", balanceOfAccount0.toNumber());
      console.log("Balance of account1 : ", balanceOfAccount1.toNumber());
      console.log("Balance of account2 : ", balanceOfAccount2.toNumber());
      console.log("Balance of account3 : ", balanceOfAccount3.toNumber());
      console.log("Balance of account4 : ", balanceOfAccount4.toNumber());

      balanceOfContract = await token.balanceOf(xStaked.address);
      expect(balanceOfContract).to.equal(20000000000000);
      console.log("Balance of contract : ", balanceOfContract.toNumber());
   });

   it('Get all stakes', async () => {
      let stakeIDs = await xStaked.getMyStakes(accounts[4].address);

      console.log("accounts4 stake count : " + stakeIDs.length);

      for (let index = 0; index < stakeIDs.length; index++) {
         console.log("Account4 stakeIndex" + index, stakeIDs[index]);
      }
   });

   it('Account5 deposit after end of acceptingDeposit', async () => {
      let balanceOfAccount5 = await token.balanceOf(accounts[5].address);
      console.log("Before deposit");
      console.log("Balance of account5 : ", balanceOfAccount5.toNumber());

      let balanceOfContract = await token.balanceOf(xStaked.address);
      expect(balanceOfContract).to.equal(20000000000000);
      console.log("Balance of contract : ", balanceOfContract.toNumber());

      console.log("About to sleep for 3 hours. Account5 deposits")
      sleep(500)
      await time.increase(3 * 60 * 60);
      await expect(xStaked.connect(accounts[5]).stake(0, balanceOfAccount5)).to.be.reverted;

      balanceOfAccount5 = await token.balanceOf(accounts[5].address);
      expect(balanceOfAccount5).to.equal(6000000000000);
      console.log("After deposit");
      console.log("Balance of account5 : ", balanceOfAccount5.toNumber());

      balanceOfContract = await token.balanceOf(xStaked.address);
      expect(balanceOfContract).to.equal(20000000000000);
      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Account5 failed to deposit, cuz ended acceptinig deposit.");
   });

   it('Manager tries to start staking again', async () => {
      console.log("About to sleep for 10 days.")
      sleep(500)
      await time.increase(10 * 24 * 60 * 60);

      await expect(xStaked.startStaking(0, 0)).to.be.reverted;

      let poolConfig = await xStaked.getPoolConfig(0);
      expect(poolConfig[0]).to.equal(30);

      console.log("Manager failed to start staking again.")
   });

   it('Manager set rewards', async () => {
      const rewards = 10000000000000;

      let contractBalance = await token.balanceOf(xStaked.address);
      console.log("Contract balance before setting rewards : " + contractBalance.toNumber());

      let ownerBalance = await token.balanceOf(owner.address);
      const dec = await token.decimals();
      console.log("Owner balance before setting rewards : " + ownerBalance);

      expect(await xStaked.addRewards(rewards));

      contractBalance = await token.balanceOf(xStaked.address);
      console.log("Contract balance after setting rewards : " + contractBalance.toNumber());

      ownerBalance = await token.balanceOf(owner.address);
      console.log("Owner balance before setting rewards : " + ownerBalance);
   });

   it('Account0 tries to withdraw before end of staking period', async () => {
      console.log("About to sleep for 10 days.")
      sleep(500)
      await time.increase(10 * 24 * 60 * 60);

      let balanceOfContract = await token.balanceOf(xStaked.address);
      let balanceOfAccount0 = await token.balanceOf(accounts[0].address);

      expect(balanceOfContract).to.equal(30000000000000);
      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account0 : ", balanceOfAccount0.toNumber());

      let stakeIDs = await xStaked.getMyStakes(accounts[0].address);

      await expect(xStaked.connect(accounts[0]).withdrawStake(stakeIDs[0])).to.be.reverted;

      console.log("After withdraw");
      balanceOfContract = await token.balanceOf(xStaked.address);
      balanceOfAccount0 = await token.balanceOf(accounts[0].address);

      expect(balanceOfContract).to.equal(30000000000000);
      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account0 : ", balanceOfAccount0.toNumber());
      console.log("Account0 failed to withdraw");

   });

   it('Get pool info', async () => {
      let info = await xStaked.getPoolInfo(1);

      console.log("poolInstance = 0");
      console.log("PoolType: " + info[0]);
      console.log("startOfDeposit: " + info[1]);
      console.log("totalStaked: " + info[2]);
      console.log("poolReward: " + info[3]);
      console.log("endOfDeposit: " + info[4]);
      console.log("PoolStatus", info[5]);
   });
   
   it('Manager set rewards again', async () => {
      const rewards = 10000000000000;

      let contractBalance = await token.balanceOf(xStaked.address);
      console.log("Contract balance before setting rewards : " + contractBalance.toNumber());

      let ownerBalance = await token.balanceOf(owner.address);
      const dec = await token.decimals();
      console.log("Owner balance before setting rewards : " + ownerBalance);

      expect(await xStaked.addRewards(rewards));

      contractBalance = await token.balanceOf(xStaked.address);
      console.log("Contract balance after setting rewards : " + contractBalance.toNumber());

      ownerBalance = await token.balanceOf(owner.address);
      console.log("Owner balance before setting rewards : " + ownerBalance);
   });

   it('Account0 tries to withdraw after end of staking period', async () => {
      console.log("About to sleep for 9 days and 22 hours.")
      sleep(500)
      await time.increase(9 * 24 * 60 * 60 + 22 * 60 * 60);

      // let pid = await xStaked.poolInstanceCounter();
      // console.log("poolInstanceCounter : ", pid);
      // let poolInfo = await xStaked.poolById(pid);
      // console.log("PoolInstance : ", poolInfo);

      let balanceOfContract = await token.balanceOf(xStaked.address);
      let balanceOfAccount0 = await token.balanceOf(accounts[0].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Address0 : ", balanceOfAccount0.toNumber());

      let stakeIDs = await xStaked.getMyStakes(accounts[0].address);;

      let rewardAmount = await xStaked.getRewards(stakeIDs[0]);
      console.log("Reward amount : ", rewardAmount.toNumber());

      await expect(xStaked.connect(accounts[0]).withdrawStake(stakeIDs[0])).to.be.not.reverted;

      await time.increase(1);

      console.log("After withdraw");

      balanceOfContract = await token.balanceOf(xStaked.address);
      balanceOfAccount0 = await token.balanceOf(accounts[0].address);
      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account0 : ", balanceOfAccount0.toNumber());
   });

   it('Account0 tries to withdraw again', async () => {
      console.log("About to sleep for 1 days")
      sleep(500)
      await time.increase(1 * 24 * 60 * 60);

      let balanceOfContract = await token.balanceOf(xStaked.address);
      let balanceOfAccount0 = await token.balanceOf(accounts[0].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account0 : ", balanceOfAccount0.toNumber());

      let stakeIDs = await xStaked.getMyStakes(accounts[0].address);

      // await expect(xStaked.getRewards(stakeIDs[0])).to.be.reverted;

      await expect(xStaked.connect(accounts[0]).withdrawStake(stakeIDs[0])).to.be.reverted;

      console.log("After withdraw");
      balanceOfContract = await token.balanceOf(xStaked.address);
      balanceOfAccount0 = await token.balanceOf(accounts[0].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Address0 : ", balanceOfAccount0.toNumber());

      console.log("fail: already paid out");
   });

   it('Manager set rewards', async () => {
      const rewards = 10000000000000;

      let contractBalance = await token.balanceOf(xStaked.address);
      console.log("Contract balance before setting rewards : " + contractBalance.toNumber());

      let ownerBalance = await token.balanceOf(owner.address);
      const dec = await token.decimals();
      console.log("Owner balance before setting rewards : " + ownerBalance);

      expect(await xStaked.addRewards(rewards));

      contractBalance = await token.balanceOf(xStaked.address);
      console.log("Contract balance after setting rewards : " + contractBalance.toNumber());

      ownerBalance = await token.balanceOf(owner.address);
      console.log("Owner balance before setting rewards : " + ownerBalance);
   });

   it('Account0 deposit before manager accept deposit - second', async () => {
      let balanceOfAccount0 = await token.balanceOf(accounts[0].address);
      console.log("Before deposit");
      console.log("Balance of account0 : ", balanceOfAccount0.toNumber());

      let balanceOfContract = await token.balanceOf(xStaked.address);
      console.log("Balance of contract : ", balanceOfContract.toNumber());

      console.log("About to sleep for 5 hours. Account0 deposits")
      sleep(500)
      await time.increase(5 * 60 * 60);
      await expect(xStaked.connect(accounts[0]).stake(0, balanceOfAccount0)).to.be.reverted;

      balanceOfContract = await token.balanceOf(xStaked.address);
      console.log("Balance of contract : ", balanceOfContract.toNumber());
   });

   it('Manager starts acceptDeposit again after staking', async () => {
      await xStaked.startStaking(0, 0);

      let poolConfig = await xStaked.getPoolConfig(0);
      expect(await poolConfig[0]).to.equal(30);

      console.log("Pool_0_PeriodStaking", poolConfig[0]);
      console.log("Pool_0_TimeAccepting", (await xStaked.getTimeAccepting(0)));
   });

   it('Account0 tries to withdraw before end of staking period - second', async () => {
      console.log("About to sleep for 2 hour.")
      sleep(500)
      await time.increase(2 * 60 * 60);

      let balanceOfContract = await token.balanceOf(xStaked.address);
      let balanceOfAccount0 = await token.balanceOf(accounts[0].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account0 : ", balanceOfAccount0.toNumber());

      let stakeIDs = await xStaked.getMyStakes(accounts[0].address);;

      await expect(xStaked.connect(accounts[0]).withdrawStake(stakeIDs[0])).to.be.reverted;

      console.log("After withdraw");
      balanceOfContract = await token.balanceOf(xStaked.address);
      balanceOfAccount0 = await token.balanceOf(accounts[0].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account0 : ", balanceOfAccount0.toNumber());
      console.log("Account0 failed to withdraw");
   });

   it('Manager set rewards again', async () => {
      const rewards = 10000000000000;

      let contractBalance = await token.balanceOf(xStaked.address);
      console.log("Contract balance before setting rewards : " + contractBalance.toNumber());

      let ownerBalance = await token.balanceOf(owner.address);
      const dec = await token.decimals();
      console.log("Owner balance before setting rewards : " + ownerBalance);

      expect(await xStaked.addRewards(rewards));

      contractBalance = await token.balanceOf(xStaked.address);
      console.log("Contract balance after setting rewards : " + contractBalance.toNumber());

      ownerBalance = await token.balanceOf(owner.address);
      console.log("Owner balance before setting rewards : " + ownerBalance);
   });

   it('Accounts deposit after manager accept deposit - second', async () => {
      let balanceOfAccount0 = await token.balanceOf(accounts[0].address);
      console.log("Before deposit");
      console.log("Balance of account0 : ", balanceOfAccount0.toNumber());

      let balanceOfContract = await token.balanceOf(xStaked.address);
      console.log("Balance of contract : ", balanceOfContract.toNumber());

      console.log("About to sleep for 6 hours. Account0 deposits")
      sleep(500)
      await time.increase(2 * 60 * 60);
      await expect(xStaked.connect(accounts[0]).stake(0, balanceOfAccount0)).to.be.not.reverted;

      balanceOfContract = await token.balanceOf(xStaked.address);
      console.log("Balance of contract : ", balanceOfContract.toNumber());
   });

   it('Get all pool instance', async () => {
      let poolInstances = await xStaked.getAllPoolInstance(0);

      console.log("All poolInstances on poolType_0: " + poolInstances);
   });

   it('Get all stakes by pool instance', async () => {
      let poolInstances = await xStaked.getAllPoolInstance(0);
      let stakeIds = await xStaked.getAllStakesByPoolInstance(poolInstances[0]);

      console.log("All stakes on poolInstance_" + poolInstances[0] + ": " + stakeIds);
   });

   it('Get all stakes by pool type', async () => {
      let stakeIds = await xStaked.getAllStakesByPoolType(0);

      console.log("All stakes on poolType_0: " + stakeIds);
   });

   it('Withdraw pool instance', async () => {
      let poolInstances = await xStaked.getMyPoolInstances(accounts[0].address);
 
      console.log("Pool instances of account_0: " + poolInstances);

      let balanceOfContract = await token.balanceOf(xStaked.address);
      let balanceOfAccount0 = await token.balanceOf(accounts[0].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account0 : ", balanceOfAccount0.toNumber());

      await expect(xStaked.connect(accounts[0]).withdrawPoolInstance(poolInstances[1])).to.be.reverted;

      console.log("After withdraw");
      balanceOfContract = await token.balanceOf(xStaked.address);
      balanceOfAccount0 = await token.balanceOf(accounts[0].address);
   });

   it('Withdraw pool', async () => {
      let poolInstances = await xStaked.getMyPoolTypes(accounts[4].address);
 
      console.log("Pool types of account_4: " + poolInstances);

      let balanceOfContract = await token.balanceOf(xStaked.address);
      let balanceOfAccount4 = await token.balanceOf(accounts[4].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account4 : ", balanceOfAccount4.toNumber());

      await xStaked.connect(accounts[4]).withdrawPoolInstance(poolInstances[0]);

      console.log("After withdraw");
      balanceOfContract = await token.balanceOf(xStaked.address);
      balanceOfAccount4 = await token.balanceOf(accounts[4].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account4 : ", balanceOfAccount4.toNumber());
   });

   it('Get pool length', async () => {
      let poolLength = await xStaked.poolLength();

      console.log("Pool length: " + poolLength);
   });

   it('Account0 tries to withdraw after end of staking period - second', async () => {
      console.log("About to sleep for 40 days.")
      sleep(500)
      await time.increase(40 * 24 * 60 * 60);

      let balanceOfContract = await token.balanceOf(xStaked.address);
      let balanceOfAccount0 = await token.balanceOf(accounts[0].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account0 : ", balanceOfAccount0.toNumber());

      let stakeIDs = await xStaked.getMyStakes(accounts[0].address);
      console.log("stakeID : ", stakeIDs[1]);
      console.log("stakeIDCounter : ", await xStaked.stakeIdCounter());

      await expect(xStaked.connect(accounts[0]).withdrawStake(stakeIDs[1])).to.be.not.reverted;

      console.log("After withdraw");
      balanceOfContract = await token.balanceOf(xStaked.address);
      balanceOfAccount0 = await token.balanceOf(accounts[0].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account0 : ", balanceOfAccount0.toNumber());
   });

   it('Account4 tries to withdraw all', async () => {
      console.log("About to sleep for 60 days.")
      sleep(500)
      await time.increase(60 * 24 * 60 * 60);

      let balanceOfContract = await token.balanceOf(xStaked.address);
      let balanceOfAccount4 = await token.balanceOf(accounts[4].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Address4 : ", balanceOfAccount4.toNumber());

      await expect(xStaked.connect(accounts[4]).withdrawAll()).to.be.not.reverted;

      console.log("After withdraw");
      balanceOfContract = await token.balanceOf(xStaked.address);
      balanceOfAccount4 = await token.balanceOf(accounts[4].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account4 : ", balanceOfAccount4.toNumber());
   });

   it('Account4 tries to withdraw after end of staking on pool_0', async () => {
      console.log("About to sleep for 60 days.")
      sleep(500)
      await time.increase(60 * 24 * 60 * 60);

      let balanceOfContract = await token.balanceOf(xStaked.address);
      let balanceOfAccount4 = await token.balanceOf(accounts[4].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Address4 : ", balanceOfAccount4.toNumber());

      let stakeIDs = await xStaked.getMyStakes(accounts[4].address);

      console.log("accounts4 stake count : " + stakeIDs.length);
      console.log("accounts4 stakeID_0 : " + stakeIDs[0]);
      console.log("accounts4 stakeID_1 : " + stakeIDs[1]);

      let rewardAmount = await xStaked.getRewards(stakeIDs[0]);
      console.log("Reward amount : ", rewardAmount.toNumber());

      await expect(xStaked.connect(accounts[4]).withdrawStake(stakeIDs[0])).to.be.reverted;

      console.log("After withdraw");
      balanceOfContract = await token.balanceOf(xStaked.address);
      balanceOfAccount4 = await token.balanceOf(accounts[4].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Account4 : ", balanceOfAccount4.toNumber());
   });

   it('Account4 tries to withdraw after end of staking on pool_4', async () => {
      console.log("About to sleep for 300 days.")
      sleep(500)
      await time.increase(300 * 24 * 60 * 60);

      let balanceOfContract = await token.balanceOf(xStaked.address);
      let balanceOfAccount4 = await token.balanceOf(accounts[4].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Address4 : ", balanceOfAccount4.toNumber());

      let stakeIDs = await xStaked.getMyStakes(accounts[4].address);

      let rewardAmount = await xStaked.getRewards(stakeIDs[1]);
      console.log("Reward amount : ", rewardAmount.toNumber());

      await expect(xStaked.connect(accounts[4]).withdrawStake(stakeIDs[1])).to.be.not.reverted;

      console.log("After withdraw");
      balanceOfContract = await token.balanceOf(xStaked.address);
      balanceOfAccount4 = await token.balanceOf(accounts[4].address);

      console.log("Balance of contract : ", balanceOfContract.toNumber());
      console.log("Balance of Address4 : ", balanceOfAccount4.toNumber());
   });

   it('Get lastes pool instances for each pool type', async () => {
      console.log('Get currnet pool', await xStaked.getCurrentPools());
   });
})
