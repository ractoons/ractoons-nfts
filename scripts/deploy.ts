import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  const Ractoons = await ethers.getContractFactory("Ractoons");
  // @ts-ignore
  const ractoons = await Ractoons.deploy(
    "ipfs://QmQ1MJ7cZTQW3i2iF9hD4oou5cC1ThJTsFcw8gLd5Xa7wm",
    deployer.address
  );

  await ractoons.deployed();
  console.log("Ractoons deployed to:", ractoons.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
