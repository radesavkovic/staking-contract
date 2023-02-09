const { expect } = require("chai");
const { ethers } = require("hardhat");
const { MockProvider } = require("ethereum-waffle");

require("@nomiclabs/hardhat-ethers");
const assert = require('assert').strict;
const { BigNumber, utils } = require("ethers");

const burnerRole = ethers.utils.id("BURNER_ROLE");
const pauserRole = ethers.utils.id("PAUSER_ROLE");

const getNumberFromBN = (bn, d) => {
  return BigNumber.from(bn).div(Math.pow(10, d)).toNumber();
}

const formatNumberFromBN = (bn, d) => {
  return (getNumberFromBN(bn, d)).toString().split("").reverse().reduce(function(acc, num, i, orig) {return num + (num != "-" && i && !(i % 3) ? "," : "") + acc;}, "");;
}

contract("UvwToken", (accounts) => {
  let uvwToken, token, owner, account1, account2;
  let dec;

  before(async () => {
    [owner, account1, account2, account3, account4, account5, account6] = await ethers.getSigners();

    uvwToken = await hre.ethers.getContractFactory('UvwToken');
    token = await uvwToken.deploy();

    await token.deployed();
    console.log("uvwToken deployed to:", token.address);

  });

  it('Check contract status', async () => {
    dec = await token.decimals();

    expect(await token.owner()).to.equal(owner.address);
    console.log("Owner address : ", owner.address);

    const ownerBalance = await token.balanceOf(owner.address);
    expect(await token.totalSupply()).to.equal(ownerBalance);
    console.log("Owner balance : ", formatNumberFromBN(ownerBalance, dec));

    expect(await token.name()).to.equal("uvwToken");
    console.log("Contract name : ", await token.name());

    expect(await token.symbol()).to.equal("UVWT");
    console.log("Contract symbol : ", await token.symbol());

    expect(await token.decimals()).to.equal(10);
    console.log("Contract decimals : ", await token.decimals());
  });

  it('Set PAUSER_ROLE to account1 and BURNER_ROLE to account2', async () => {
    await token.grantRole(pauserRole, account1.address);
    expect(await token.hasRole(pauserRole, account1.address)).to.equal(true);

    await token.grantRole(burnerRole, account2.address);
    expect(await token.hasRole(burnerRole, account2.address)).to.equal(true);

    expect(await token.hasRole(pauserRole, owner.address)).to.equal(false);
    expect(await token.hasRole(burnerRole, owner.address)).to.equal(false);

    expect(await token.hasRole(burnerRole, account1.address)).to.equal(false);

    expect(await token.hasRole(pauserRole, account2.address)).to.equal(false);

    await token.revokeRole(burnerRole, account2.address);
    expect(await token.hasRole(burnerRole, account2.address)).to.equal(false);

    await token.grantRole(burnerRole, account2.address);
    expect(await token.hasRole(burnerRole, account2.address)).to.equal(true);

    console.log("Account1 has PAUSER_ROLE");
    console.log("account2 has BURNER_ROLE");
  });

  it('Should transfer tokens between accounts', async () => {
    await token.transfer(account1.address, 500000000000);
    let account1Balance = await token.balanceOf(account1.address);
    expect(account1Balance).to.equal(500000000000);

    await token.connect(account1).transfer(account2.address, 250000000000);
    const account2Balance = await token.balanceOf(account2.address);
    expect(account2Balance).to.equal(250000000000);

    const ownerBalance = await token.balanceOf(owner.address);
    account1Balance = await token.balanceOf(account1.address);

    console.log("Owner Balance : ", formatNumberFromBN(ownerBalance, dec));
    console.log("Account1 Balance : ", formatNumberFromBN(account1Balance, dec));
    console.log("Account2 Balance : ", formatNumberFromBN(account2Balance, dec));
  });

  it('Should failed transfer negative tokens between accounts', async () => {
    console.log("Trying to transfer -1 to account1");
    await expect(token.transfer(account1.address, -100000000000)).to.be.reverted;
    let account1Balance = await token.balanceOf(account1.address);
    expect(account1Balance).to.equal(250000000000);

    await expect(token.connect(account1).transfer(account2.address, -100000000000)).to.be.reverted;
    const account2Balance = await token.balanceOf(account2.address);
    expect(account2Balance).to.equal(250000000000);

    const ownerBalance = await token.balanceOf(owner.address);
    account1Balance = await token.balanceOf(account1.address);

    console.log("Owner Balance : ", formatNumberFromBN(ownerBalance, dec));
    console.log("Account1 Balance : ", formatNumberFromBN(account1Balance, dec));
    console.log("Account2 Balance : ", formatNumberFromBN(account2Balance, dec));
  });

  it('Should failed transfer tokens from account with zero balance', async () => {
    let account2Balance = await token.balanceOf(account2.address);
    let account3Balance = await token.balanceOf(account3.address);
    console.log("Account2 Balance : ", formatNumberFromBN(account2Balance, dec));
    console.log("Account3 Balance : ", formatNumberFromBN(account3Balance, dec));

    console.log("Trying to transfer 10 from account3 to account2");

    await expect(token.connect(account3).transfer(account2.address, 1000000000000)).to.be.reverted;
    account2Balance = await token.balanceOf(account2.address);
    expect(account2Balance).to.equal(250000000000);

    account3Balance = await token.balanceOf(account3.address);

    console.log("Account2 Balance : ", formatNumberFromBN(account2Balance, dec));
    console.log("Account3 Balance : ", formatNumberFromBN(account3Balance, dec));
  });


  it('Should fail to transfer 2 tokens when balance is 1 token', async () => {
    await token.transfer(account4.address, 1)

    let account4Balance = await token.balanceOf(account4.address);
    let account5Balance = await token.balanceOf(account5.address);
    console.log("Account4 Balance : ", formatNumberFromBN(account4Balance, 0));
    console.log("Account5 Balance : ", formatNumberFromBN(account5Balance, 0));

    console.log("Trying to transfer 2 from account4 to account5");

    await expect(token.connect(account4).transfer(account5.address, 2)).to.be.reverted;
    account4Balance = await token.balanceOf(account4.address);
    account5Balance = await token.balanceOf(account5.address);
    expect(account4Balance).to.equal(1);
    expect(account5Balance).to.equal(0);
    console.log("Account4 Balance : ", formatNumberFromBN(account4Balance, 0));
    console.log("Account5 Balance : ", formatNumberFromBN(account5Balance, 0));
  });

  it('Should fail to transfer 2 tokens when balance is 1 tokens in base units', async () => {
    await token.transfer(account5.address, 10000000000)

    let account5Balance = await token.balanceOf(account5.address);
    let account6Balance = await token.balanceOf(account6.address);
    console.log("Account5 Balance : ", formatNumberFromBN(account5Balance, dec));
    console.log("Account6 Balance : ", formatNumberFromBN(account6Balance, dec));

    console.log("Trying to transfer 2 from account5 to account6");

    await expect(token.connect(account5).transfer(account5.address, 20000000000)).to.be.reverted;
    account5Balance = await token.balanceOf(account5.address);
    account6Balance = await token.balanceOf(account6.address);
    expect(account5Balance).to.equal(10000000000);
    expect(account6Balance).to.equal(0);
    console.log("Account5 Balance : ", formatNumberFromBN(account5Balance, dec));
    console.log("Account6 Balance : ", formatNumberFromBN(account6Balance, dec));
  });

  it('Should failed transfer tokens that are greater than current balance', async () => {
    let account1Balance = await token.balanceOf(account1.address);
    let account2Balance = await token.balanceOf(account2.address);
    console.log("Account1 Balance : ", formatNumberFromBN(account1Balance, dec));
    console.log("Account2 Balance : ", formatNumberFromBN(account2Balance, dec));

    console.log("Account1 tries to transfer 50 Token to account2");
    await expect(token.connect(account1).transfer(account2.address, 500000000000)).to.be.reverted;
    account1Balance = await token.balanceOf(account1.address);
    account2Balance = await token.balanceOf(account2.address);
    expect(account1Balance).to.equal(250000000000);
    expect(account2Balance).to.equal(250000000000);

    console.log("Account1 Balance : ", formatNumberFromBN(account1Balance, dec));
    console.log("Account2 Balance : ", formatNumberFromBN(account2Balance, dec));
  });

  it('Account1 set pause to true with PAUSER_ROLE', async () => {
    expect(await token.paused()).to.equal(false);
    console.log("Pause is false before account1 set pause");

    await expect(token.connect(account1).pause()).to.be.not.reverted;
    let paused = await token.paused();
    expect(paused).to.equal(true);
    console.log("Pause is true after account1 set pause");
  });

  it('Failed transfer tokens between accounts when paused', async () => {
    let account1Balance = await token.balanceOf(account1.address);
    let account2Balance = await token.balanceOf(account2.address);
    console.log("Account1 balance before trying to transfer : ", formatNumberFromBN(account1Balance, dec));
    console.log("Account2 balance before trying to transfer : ", formatNumberFromBN(account2Balance, dec));

    await expect(token.connect(account1).transfer(account2.address, 100000000000)).to.be.reverted;

    account1Balance = await token.balanceOf(account1.address);
    expect(account1Balance).to.equal(250000000000);
    account2Balance = await token.balanceOf(account2.address);
    expect(account2Balance).to.equal(250000000000);

    console.log("Account1 balance after trying to transfer : ", formatNumberFromBN(account1Balance, dec));
    console.log("Account2 balance after trying to transfer : ", formatNumberFromBN(account2Balance, dec));

    console.log("Token transfer is failed because pause is true");
  });

  it('Account2 tries to set pause to false without PAUSER_ROLE', async () => {
    let paused = await token.paused();
    expect(paused).to.equal(true);
    console.log("Pause is true before account2 tries set pause");

    await expect(token.connect(account2).unpause()).to.be.reverted;
    paused = await token.paused();
    expect(paused).to.equal(true);
    console.log("Pause is true after account2 tries to set pause");
  });

  it('Account1 set pause to false with PAUSER_ROLE', async () => {
    await expect(token.connect(account1).unpause()).to.be.not.reverted;
  });

  it('Account2 burn token with BURNER_ROLE', async () => {
    expect(await token.hasRole(burnerRole, account2.address)).to.equal(true);

    let totalSupply = await token.totalSupply();
    let account2Balance = await token.balanceOf(account2.address);
    console.log("TotalSupply before account2 burn token : ", formatNumberFromBN(totalSupply, dec));
    console.log("Account2 Balance before account2 burn token : ", formatNumberFromBN(account2Balance, dec));

    await expect(token.connect(account2).burnToken(account2.address, 100000000000)).to.be.not.reverted;

    totalSupply = await token.totalSupply();
    account2Balance = await token.balanceOf(account2.address);

    expect(getNumberFromBN(totalSupply, dec)).to.equal(999999990);
    expect(account2Balance).to.equal(150000000000);

    console.log("TotalSupply after account2 burn token : ", formatNumberFromBN(totalSupply, dec));
    console.log("Account2 Balance after account2 burn token : ", formatNumberFromBN(account2Balance, dec));
  });

  it('Account1 tries to burn token without BURNER_ROLE, but failed', async () => {
    expect(await token.hasRole(burnerRole, account1.address)).to.equal(false);

    let totalSupply = await token.totalSupply();
    let account1Balance = await token.balanceOf(account1.address);
    console.log("TotalSupply before account1 tries to burn token : ", formatNumberFromBN(totalSupply, dec));
    console.log("Account1 Balance before account1 tries to burn token : ", formatNumberFromBN(account1Balance, dec));

    await expect(token.connect(account1).burnToken(account1.address, 100000000000)).to.be.reverted;

    totalSupply = await token.totalSupply();
    account1Balance = await token.balanceOf(account1.address);

    expect(getNumberFromBN(totalSupply, dec)).to.equal(999999990);
    expect(account1Balance).to.equal(250000000000);

    console.log("TotalSupply after account1 tries to burn token : ", formatNumberFromBN(totalSupply, dec));
    console.log("Account1 Balance after account1 tries to burn token : ", formatNumberFromBN(account1Balance, dec));
  });

  it('Should add account2 to blacklist', async () => {
    let account2BlacklistStatus = await token.getBlackListStatus(account2.address);
    let account2Balance = await token.balanceOf(account2.address);
    expect(account2BlacklistStatus).to.equal(false);
    console.log("Account2 is not in blacklist before owner add him to blacklist");
    console.log("Account2 balance before : ", formatNumberFromBN(account2Balance, dec));

    await expect(token.addBlackList(account2.address)).to.be.not.reverted;
    account2BlacklistStatus = await token.getBlackListStatus(account2.address);
    expect(account2BlacklistStatus).to.equal(true);
    console.log("Account2 is in blacklist");

    await expect(token.connect(account2).transfer(account1.address, 100000000000)).to.be.reverted;

    account2Balance = await token.balanceOf(account2.address);
    console.log("Account2 balance after : ", formatNumberFromBN(account2Balance, dec));
  });

  it('Should remove account2 from blacklist', async () => {
    let account2BlacklistStatus = await token.getBlackListStatus(account2.address);
    let account2Balance = await token.balanceOf(account2.address);
    expect(account2BlacklistStatus).to.equal(true);
    console.log("Account2 is in blacklist before owner add him to blacklist");
    console.log("Account2 balance before : ", formatNumberFromBN(account2Balance, dec));

    await expect(token.removeBlackList(account2.address)).to.be.not.reverted;

    account2BlacklistStatus = await token.getBlackListStatus(account2.address);
    expect(account2BlacklistStatus).to.equal(false);
    console.log("Account2 is not in blacklist");

    await expect(token.connect(account2).transfer(account1.address, 100000000000)).to.be.not.reverted;

    account2Balance = await token.balanceOf(account2.address);
    console.log("Account2 balance after : ", formatNumberFromBN(account2Balance, dec));
  });

  it('Account3 cant transfer before approve', async () => {
    let account2Balance = await token.balanceOf(account2.address);
    console.log("Account2 balance before : ", formatNumberFromBN(account2Balance, dec));

    await expect(token.connect(account3).transferFrom(account2.address, account3.address, 30000000000)).to.be.reverted;

    account2Balance = await token.balanceOf(account2.address);
    console.log("Account2 balance after : ", formatNumberFromBN(account2Balance, dec));
  });

  it('Account3 can transfer after approve', async () => {
    let account2Balance = await token.balanceOf(account2.address);
    console.log("Account2 balance before : ", formatNumberFromBN(account2Balance, dec));

    let account3Balance = await token.balanceOf(account3.address);
    console.log("Account3 balance before : ", formatNumberFromBN(account3Balance, dec));

    await token.connect(account2).approve(account3.address, 20000000000);
    
    await expect(token.connect(account3).transferFrom(account2.address, account3.address, 20000000000)).to.be.not.reverted;

    account2Balance = await token.balanceOf(account2.address);
    console.log("Account2 balance after : ", formatNumberFromBN(account2Balance, dec));

    account3Balance = await token.balanceOf(account3.address);
    console.log("Account3 balance after : ", formatNumberFromBN(account3Balance, dec));
  });

  it('Account2 is in blacklist and account2 cant approve', async () => {
    await expect(token.addBlackList(account2.address)).to.be.not.reverted;

    let account2Balance = await token.balanceOf(account2.address);
    console.log("Account2 balance before : ", formatNumberFromBN(account2Balance, dec));

    let account3Balance = await token.balanceOf(account3.address);
    console.log("Account3 balance before : ", formatNumberFromBN(account3Balance, dec));

    await expect(token.connect(account2).approve(account3.address, 20000000000)).to.be.reverted;

    await expect(token.connect(account2).transferFrom(account2.address, account3.address, 20000000000)).to.be.reverted;

    account2Balance = await token.balanceOf(account2.address);
    console.log("Account2 balance after : ", formatNumberFromBN(account2Balance, dec));

    account3Balance = await token.balanceOf(account3.address);
    console.log("Account3 balance after : ", formatNumberFromBN(account3Balance, dec));
  });

  it('Destroy fund of blacklist - Account2', async () => {
    let account2Balance = await token.balanceOf(account2.address);
    console.log("Account2 balance before : ", formatNumberFromBN(account2Balance, dec));

    await token.destroyBlackFunds(account2.address);

    account2Balance = await token.balanceOf(account2.address);
    console.log("Account2 balance after : ", formatNumberFromBN(account2Balance, dec));
  });
})
