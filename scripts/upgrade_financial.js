// scripts/upgrade_box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const FinancialV2 = await ethers.getContractFactory("FinancialV2");
  console.log("Upgrading Financial...");
  const financial = await upgrades.upgradeProxy("0xfB1B806d50690d9E4454575F48bb44e82f4a10D7", FinancialV2);
  console.log("Financial upgraded");
}

main();