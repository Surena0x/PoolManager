const hre = require("hardhat");

async function main() {
  const rewardPerBlock = ethers.utils.parseEther("10");
  const startBlock = 10670446;
  const endBlock = 10869796;

  /// /////////////////////////////////////////////// KING TOKEN TO STAKE
  const KingToken = await ethers.getContractFactory("MockERC20");
  const KingTokenContract = await KingToken.deploy(
    "KING",
    "KING",
    ethers.utils.parseEther("1000")
  );
  await KingTokenContract.deployed();
  console.log("KingTokenContract deployed to:", KingTokenContract.address);

  /// /////////////////////////////////////////////// DAI TOKEN TO GIVE REWARD
  const DAIToken = await ethers.getContractFactory("MockERC20");
  const DAITokenContract = await DAIToken.deploy(
    "DAI",
    "DAI",
    ethers.utils.parseEther("1000")
  );
  await DAITokenContract.deployed();
  console.log("DAITokenContract deployed to:", DAITokenContract.address);

  const BNBToken = await ethers.getContractFactory("MockERC20");
  const BNBTokenContract = await BNBToken.deploy(
    "WBNB",
    "WBNB",
    ethers.utils.parseEther("1000")
  );
  await BNBTokenContract.deployed();
  console.log("BNBTokenContract deployed to:", BNBTokenContract.address);

  const CakeToken = await ethers.getContractFactory("MockERC20");
  const CakeTokenContract = await CakeToken.deploy(
    "CAKE",
    "CAKE",
    ethers.utils.parseEther("1000")
  );
  await CakeTokenContract.deployed();
  console.log("CakeTokenContract deployed to:", CakeTokenContract.address);

  /// /////////////////////////////////////////////// DATA STORAGE CONTRACT
  const ChefStorage = await ethers.getContractFactory("DataStorage");
  const ChefStorageContract = await ChefStorage.deploy();
  await ChefStorageContract.deployed();

  console.log("ChefStorageContract deployed to:", ChefStorageContract.address);

  /// /////////////////////////////////////////////// MANAGER CONTRACT
  const ChefManager = await ethers.getContractFactory("Manager");
  const ChefManagerContract = await ChefManager.deploy(
    KingTokenContract.address
  );
  await ChefManagerContract.deployed();

  console.log("ChefManagerContract deployed to:", ChefManagerContract.address);

  /// /////////////////////////////////////////////// SETUP
  await ChefManagerContract.setPoolManagerDataStorage(
    ChefStorageContract.address
  );

  /// /////////////////////////////////////////////// CHARGE MANAGER POOL BY DAI TOKEN
  await DAITokenContract.approve(
    ChefManagerContract.address,
    ethers.utils.parseEther("1000")
  );
  await DAITokenContract.transfer(
    ChefManagerContract.address,
    ethers.utils.parseEther("1000")
  );

  await BNBTokenContract.approve(
    ChefManagerContract.address,
    ethers.utils.parseEther("1000")
  );
  await BNBTokenContract.transfer(
    ChefManagerContract.address,
    ethers.utils.parseEther("1000")
  );

  await CakeTokenContract.approve(
    ChefManagerContract.address,
    ethers.utils.parseEther("1000")
  );
  await CakeTokenContract.transfer(
    ChefManagerContract.address,
    ethers.utils.parseEther("1000")
  );

  /// /////////////////////////////////////////////// NOW CREATE  POOLS

  await ChefManagerContract.createPool(
    DAITokenContract.address,
    rewardPerBlock,
    startBlock,
    endBlock
  );

  await ChefManagerContract.createPool(
    BNBTokenContract.address,
    rewardPerBlock,
    startBlock,
    endBlock
  );

  await ChefManagerContract.createPool(
    CakeTokenContract.address,
    rewardPerBlock,
    startBlock,
    endBlock
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
