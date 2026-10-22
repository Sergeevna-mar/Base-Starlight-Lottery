const hre = require("hardhat");
async function main() {
  const LotteryFactory = await hre.ethers.getContractFactory("StarlightLotteryPool");
  const lottery = await LotteryFactory.deploy();
  await lottery.deployed();
  console.log("-> Starlight Lottery Protocol initialized at:", lottery.address);
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
