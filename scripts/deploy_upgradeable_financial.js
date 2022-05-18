// scripts/deploy_upgradeable_box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const Financial = await ethers.getContractFactory("Financial");
  console.log("Deploying Financial...");
  const financial = await upgrades.deployProxy(Financial,
      [
          "0xd77c380478C7e7F6b8ED195312d3B5bEd28763e9"
      ]);
  await financial.deployed();
  console.log("Financial deployed to:", financial.address);

  const curr2 = await upgrades.admin.getInstance();
  console.log("curr2:", curr2.address);

//   const curr4 = await upgrades.erc1967.getImplementationAddress(mint.address);
//   console.log("curr4:", curr4.address);


}

main();