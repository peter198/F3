// scripts/upgrade_box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const MarketV2 = await ethers.getContractFactory("MarketV2");
  console.log("Upgrading Market...");
  const market = await upgrades.upgradeProxy("0x3293Af238370F6C342d58C8A573B740959B3A238", MarketV2);
  console.log("Market upgraded");
}

main();