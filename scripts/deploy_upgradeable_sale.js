// scripts/deploy_upgradeable_box.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const Sale = await ethers.getContractFactory("Sale");
  console.log("Deploying Sale...");
  const sale = await upgrades.deployProxy(Sale,
      [
          "0x09d3BE0c4E0cAc230Fbad75e15b5B16cB9593bF2",
          "0xF32C19d9Cff0fa957efd565F89Fda061F500cac8",
      ]);
  await sale.deployed();
  console.log("Sale deployed to:", sale.address);

  const curr2 = await upgrades.admin.getInstance();
  console.log("curr2:", curr2.address);

//   const curr4 = await upgrades.erc1967.getImplementationAddress(mint.address);
//   console.log("curr4:", curr4.address);


}

main();