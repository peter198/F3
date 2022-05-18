// scripts/deploy_upgradeable_box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const Market = await ethers.getContractFactory("Market");
  console.log("Deploying market...");
  const market = await upgrades.deployProxy(Market,
      [
          "0x09d3BE0c4E0cAc230Fbad75e15b5B16cB9593bF2",
          1000
      ]);
  await market.deployed();
  console.log("market deployed to:", market.address);

  const curr2 = await upgrades.admin.getInstance();
  console.log("curr2:", curr2.address);


}

main();