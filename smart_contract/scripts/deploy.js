async function main() {
    const AIMarketplace = await ethers.getContractFactory("AIMarketplace");
    const marketplace = await AIMarketplace.deploy();
    await marketplace.deployed();
    console.log("AIMarketplace deployed to:", marketplace.address);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
