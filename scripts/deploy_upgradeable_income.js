// scripts/deploy_upgradeable_box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const Income = await ethers.getContractFactory("Income");
  console.log("Deploying income...");
  const income = await upgrades.deployProxy(Income,[]);
  await income.deployed();
  console.log("Income deployed to:", income.address);

  const curr2 = await upgrades.admin.getInstance();
  console.log("curr2:", curr2.address);

//   const curr4 = await upgrades.erc1967.getImplementationAddress(mint.address);
//   console.log("curr4:", curr4.address);


}

main();