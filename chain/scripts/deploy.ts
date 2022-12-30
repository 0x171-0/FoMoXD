import { ethers, upgrades } from "hardhat";

async function main() {
  const [deployer, dev1, dev2] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  /* ------------------------ ERC20 ----------------------- */
  const PXD = await ethers.getContractFactory("PXD");
  const pxd = await PXD.deploy(10 ** 6, "PowHXD", "FXD");
  console.log(`[PXD] Deployed to ${pxd.address}`);
  /* ----------------------- ERC721 ----------------------- */
  const FoMoERC721 = await ethers.getContractFactory("FoMoERC721");
  const foMoERC721 = await upgrades.deployProxy(FoMoERC721, [
    "fomoERC721",
    "FMO",
    "https://raw.githubusercontent.com/0x171-0/fomoxd/dev/webapp/public/nfts/json/mystery_box.json",
  ]);

  await foMoERC721.setRoundMysteryURI(
    2,
    "https://raw.githubusercontent.com/0x171-0/fomoxd/dev/webapp/public/nfts/json/mystery_1.json"
  );

  await foMoERC721.setRoundMysteryURI(
    3,
    "https://raw.githubusercontent.com/0x171-0/fomoxd/dev/webapp/public/nfts/json/mystery_2.json"
  );

  await foMoERC721.setBaseURI(
    "https://raw.githubusercontent.com/0x171-0/fomoxd/dev/webapp/public/nfts/json/"
  );

  console.log(`[FoMoERC721] Deployed to ${foMoERC721.address}`);
  /* ---------------------- Community --------------------- */
  const Community = await ethers.getContractFactory("Community");
  const community = await Community.deploy(
    [deployer.address, dev1.address, dev2.address],
    2
  );
  /* --------------------- PlayerBook --------------------- */
  const PlayerBook = await ethers.getContractFactory("PlayerBook");
  const playerBook = await PlayerBook.deploy(community.address);
  console.log(`[PlayerBook] Deployed to ${playerBook.address}`);
  /* ----------------------- Divies ----------------------- */
  const Divies = await ethers.getContractFactory("Divies");
  const divies = await Divies.deploy(pxd.address);
  console.log(`[Divies] Deployed to ${divies.address}`);
  console.log(`[Community] Deployed to ${community.address}`);
  /* ----------------------- Oracle ----------------------- */
  const NumOracle = await ethers.getContractFactory("SimpleNumOracle");
  const numOracle = await NumOracle.deploy(1);
  /* ----------------------- FoMoXD ----------------------- */
  const FoMoXD = await ethers.getContractFactory("FoMoXD");
  const foMoXD = await FoMoXD.deploy(
    playerBook.address,
    community.address,
    pxd.address,
    foMoERC721.address,
    divies.address,
    numOracle.address
  );
  console.log(`[FoMoXD] Deployed to ${foMoXD.address}`);

  const otherFoMo = await FoMoXD.deploy(
    playerBook.address,
    community.address,
    pxd.address,
    foMoERC721.address,
    divies.address,
    numOracle.address
  );
  console.log(`[Other FoMoXD] Deployed to ${otherFoMo.address}`);
  /* ---------------------- set fomo ---------------------- */
  await foMoXD.setOtherFomo(otherFoMo.address);
  await numOracle.setFoMoGame(foMoXD.address);
  await foMoERC721.setFoMoGame(foMoXD.address);
  await playerBook.addGame(foMoXD.address, "FoMoXDTest");
  // TODO: Just For testing
  await foMoXD.activate();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// await (
//   await ethers.getContractAt(
//     "FoMoXD",
//     ""
//   )
// ).activate();
