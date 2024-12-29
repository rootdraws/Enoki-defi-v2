async function main() {
    const HelloCorn = await ethers.getContractFactory("HelloCorn");
    const helloCorn = await HelloCorn.deploy();
  
    await helloCorn.waitForDeployment();
    console.log("HelloCorn deployed to:", await helloCorn.getAddress());
  }
  
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});