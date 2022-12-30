import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { network, ethers, upgrades, waffle } from "hardhat";
import SnapshotHepler from "./SnapshotHelper";
import { minETHAllowed_, Teams } from "./testConfig";
import { formatUnits, parseEther, parseUnits } from "ethers/lib/utils";
import { SimpleNumOracle__factory } from "../typechain-types";
const { deployMockContract, provider } = waffle;

describe("FoMoXD", function () {
  async function deployFoMoFixture() {
    const [owner, player1, player2, player3, dev1, dev2, otherAccount] =
      await ethers.getSigners();

    const PXD = await ethers.getContractFactory("PXD");
    const pxd = await PXD.deploy(10 ** 6, "PowHXD", "FXD");

    const FOMOERC721_MYSTERY_BOX_IMAGE_URI =
      "https://ipfs.io/ipfs/egqoirncqioryqeogejxuxthoqh4q/";

    const FoMoERC721 = await ethers.getContractFactory("FoMoERC721");
    const foMoERC721 = await upgrades.deployProxy(FoMoERC721, [
      "fomoERC721",
      "FMO",
      FOMOERC721_MYSTERY_BOX_IMAGE_URI,
    ]);

    const Divies = await ethers.getContractFactory("Divies");
    const divies = await Divies.deploy(pxd.address);

    const Community = await ethers.getContractFactory("Community");
    const community = await Community.deploy(
      [owner.address, dev1.address, dev2.address],
      2
    );

    const PlayerBook = await ethers.getContractFactory("PlayerBook");
    const playerBook = await PlayerBook.deploy(community.address);

    const NumOracle = await ethers.getContractFactory("SimpleNumOracle");
    const numOracle = await NumOracle.deploy(1);
    const mockedNumOracle = await deployMockContract(
      owner,
      SimpleNumOracle__factory.abi
    );

    const FoMoXD = await ethers.getContractFactory("FoMoXD");
    const foMoXD = await FoMoXD.deploy(
      playerBook.address,
      community.address,
      pxd.address,
      foMoERC721.address,
      divies.address,
      mockedNumOracle.address
    );

    await mockedNumOracle.mock.setFoMoGame.returns();
    await mockedNumOracle.setFoMoGame(foMoXD.address);
    await mockedNumOracle.mock.isAirdrop.returns(false);
    await mockedNumOracle.mock.isAirdropNfts.returns(false);

    await numOracle.setFoMoGame(foMoXD.address);
    await foMoERC721.setFoMoGame(foMoXD.address);

    const otherFoMo = await FoMoXD.deploy(
      playerBook.address,
      community.address,
      pxd.address,
      foMoERC721.address,
      divies.address,
      mockedNumOracle.address
    );

    await foMoXD.setOtherFomo(otherFoMo.address);

    await playerBook.addGame(foMoXD.address, "FoMoXDTest");

    const snapshot = new SnapshotHepler(foMoXD);

    return {
      owner,
      foMoXD,
      otherFoMo,
      snapshot,
      player1,
      player2,
      player3,
      otherAccount,
      dev1,
      dev2,
      mockedNumOracle,
      foMoERC721,
    };
  }

  describe("Deployment", function () {
    it("Should activate game and begin new round", async function () {
      const { foMoXD, snapshot } = await loadFixture(deployFoMoFixture);
      let { roundID_, activated_, roundInitTime_, roundGapTime_ } =
        await snapshot.getConfigSnapshot();
      expect(activated_).to.equal(false);
      expect(roundID_).to.equal(0);
      await foMoXD.activate();
      ({ roundID_, activated_ } = await snapshot.getConfigSnapshot());
      const roundData = await snapshot.getRoundSnapshot(+roundID_);
      const {
        winnerId,
        winnerTeamId,
        endTime,
        ended,
        startTime,
        puffs,
        eth,
        pot,
        mask,
      } = roundData;
      expect(activated_).to.equal(true);
      expect(roundID_).to.equal(1);
      expect(winnerId).to.equal(0);
      expect(winnerTeamId).to.equal(0);
      expect(ended).to.equal(false);
      expect(puffs).to.equal(0);
      expect(eth).to.equal(0);
      expect(pot).to.equal(0);
      expect(mask).to.equal(0);
      expect(+endTime - +startTime).to.equal(+roundGapTime_ + +roundInitTime_);
    });
  });

  describe("Purchase Puffs", function () {
    describe("States", function () {
      describe("Player Id", function () {
        it("Should assign player id increasing (by 1) & init player data", async function () {
          const { foMoXD, snapshot } = await loadFixture(deployFoMoFixture);
          const players = await ethers.getSigners();
          await foMoXD.activate();
          /* ------------------------ Puffs ----------------------- */
          let lastPuffsGot = Infinity;
          for (const [index, p] of players.entries()) {
            const depositETHAmount = +parseUnits("1000", "gwei") + 1;
            await foMoXD.connect(p).buyXid(Teams.CHOCO, 0, {
              value: depositETHAmount,
            });
            expect(await foMoXD.connect(p).playerIDxAddr_(p.address)).to.equal(
              index + 1
            );

            const { player_, playerRoundsData_ } =
              await snapshot.getPlayerSnapshot(1, index + 1);
            const {
              addr, // player address
              // name, // player name
              winningVault, // winnings vault
              generalVault, // general vault
              affiliateVault, // affiliate vault
              lastRound, // last round played
              lastAffiliateId, // last affiliate id used
            } = player_;
            const { eth, puffs, mask } = playerRoundsData_;

            expect(lastRound).to.equal(1);
            expect(addr).to.equal(p.address);
            expect(winningVault).to.equal(0);
            expect(generalVault).to.equal(0);
            expect(affiliateVault).to.equal(0);
            expect(lastAffiliateId).to.equal(0);
            expect(eth).to.equal(depositETHAmount);

            /* -------------- puff price should goes up ------------- */
            expect(+puffs).to.gte(0);
            expect(+puffs).to.lte(lastPuffsGot);
            expect(mask).to.gte(0);
            lastPuffsGot = +puffs;
          }
        });
      });

      describe("Puffs Price", function () {
        it("Should be able to buy X puffs with predictable price", async function () {
          const { foMoXD, snapshot, player1 } = await loadFixture(
            deployFoMoFixture
          );
          const puffsQty = 5n * 10n ** 18n;
          const value = await foMoXD.iWantXPuffs(puffsQty);
          await foMoXD.activate();
          /* ------------------------ Puffs ----------------------- */
          await foMoXD.connect(player1).buyXid(Teams.CHOCO, 0, {
            value,
          });
          await foMoXD.connect(player1).playerIDxAddr_(player1.address);
          let { player_, playerRoundsData_ } = await snapshot.getPlayerSnapshot(
            1,
            2
          );
          const { eth, puffs, mask } = playerRoundsData_;
          expect(eth).to.equal(value);
          expect(puffs).to.equal(puffsQty);
          expect(mask).to.equal(0);
          return;
        });
      });

      describe("Timers", function () {
        it("Should add up times purchase at least 1 key", async function () {
          const { foMoXD, snapshot, player1 } = await loadFixture(
            deployFoMoFixture
          );
          const { roundIncTime_ } = await snapshot.getConfigSnapshot();
          await foMoXD.activate();
          await time.increase(240);
          for (const [index, puffsQty] of [1, 2, 3, 4].entries()) {
            const timeLeftBeforePurchases = await foMoXD.getTimeLeft();
            const value = await foMoXD.iWantXPuffs(
              BigInt(puffsQty) * 10n ** 18n
            );
            await foMoXD.connect(player1).buyXid(Teams.CHOCO, 0, {
              value: value,
            });
            const timeLeftAfterPurchases = await foMoXD.getTimeLeft();
            expect(
              +timeLeftAfterPurchases -
                +timeLeftBeforePurchases -
                +roundIncTime_ * puffsQty
            ).lte(1);
            let roundData = await snapshot.getRoundSnapshot(1);
            const { winnerId, winnerTeamId, endTime, ended, startTime } =
              roundData;
            expect(ended).to.eql(false);
            expect(+winnerTeamId).to.eql(0);
            expect(+winnerId).to.eql(2);
            expect(endTime).to.gte(startTime);
          }
        });

        it("Should end game when purchase after round end time", async function () {
          const { foMoXD, snapshot, player1, player2 } = await loadFixture(
            deployFoMoFixture
          );
          await foMoXD.activate();
          const value = await foMoXD.iWantXPuffs(BigInt(1) * 10n ** 18n);
          await foMoXD.connect(player1).buyXid(Teams.BANA, 0, {
            value: value,
          });
          let roundData = await snapshot.getRoundSnapshot(1);
          let { winnerId, winnerTeamId, endTime, ended, startTime } = roundData;
          expect(ended).to.eql(false);
          expect(+winnerTeamId).to.eql(1);
          expect(+winnerId).to.eql(2);
          expect(endTime).to.gte(startTime);

          await time.increase(10 * 60);

          const triggerEndRoundTx = await foMoXD
            .connect(player2)
            .buyXid(Teams.CHOCO, 0, {
              value: value,
            });
          let { player_: player_2, playerRoundsData_: playerRoundsData_2 } =
            await snapshot.getPlayerSnapshot(1, 3);
          await expect(triggerEndRoundTx).to.emit(foMoXD, "onEndRound");

          // Should add player2 msg.value to generalVault
          expect(player_2.generalVault).to.equal(value);
          roundData = await snapshot.getRoundSnapshot(1);
          ({ winnerId, winnerTeamId, endTime, ended, startTime } = roundData);

          expect(winnerId).to.equal(2);
          expect(winnerTeamId).to.equal(Teams.BANA);
          expect(ended).to.equal(true);
        });
      });

      describe("Rounds", function () {
        it("Should add up rounds value, eth, puffs...", async function () {
          let lastEth;
          let lastPuffs;
          let lastMask;
          const { foMoXD, snapshot, player1 } = await loadFixture(
            deployFoMoFixture
          );
          await foMoXD.activate();
          const players = await ethers.getSigners();
          for (const [index, p] of players.entries()) {
            const depositETHAmount = +parseUnits("1000", "gwei") + 1;
            await foMoXD.connect(p).buyPuffXAddr(Teams.CHOCO, player1.address, {
              value: depositETHAmount,
            });
            let { playerRoundsData_ } = await snapshot.getPlayerSnapshot(
              1,
              index + 1
            );
            lastEth = lastEth
              ? playerRoundsData_.eth.add(lastEth)
              : playerRoundsData_.eth;
            lastPuffs = lastPuffs
              ? playerRoundsData_.puffs.add(lastPuffs)
              : playerRoundsData_.puffs;
            lastMask = lastMask
              ? playerRoundsData_.mask.add(lastMask)
              : playerRoundsData_.mask;
          }
          const roundData = await snapshot.getRoundSnapshot(1);
          expect(roundData.puffs).to.lte(lastPuffs);
          expect(roundData.eth).to.equal(lastEth);
          expect(roundData.mask).to.gte(lastMask);
        });
      });
    });

    // describe("Validations", function () {});

    describe("Events", function () {
      it("Should emit an event on purchase", async function () {
        const { foMoXD, player1, mockedNumOracle } = await loadFixture(
          deployFoMoFixture
        );
        await mockedNumOracle.mock.isAirdrop.returns(false);
        await mockedNumOracle.mock.isAirdropNfts.returns(false);
        await foMoXD.activate();
        await expect(
          foMoXD.connect(player1).buyXid(Teams.CHOCO, 0, {
            value: parseUnits("1", "ether"),
          })
        ).to.emit(foMoXD, "onBuyPuff");
      });

      describe("Airdrop", function () {
        it("Should emit an event on ETH airdrop", async function () {
          const { foMoXD, player1, mockedNumOracle } = await loadFixture(
            deployFoMoFixture
          );
          await mockedNumOracle.mock.isAirdrop.returns(true);
          await foMoXD.activate();
          await expect(
            foMoXD.connect(player1).buyXid(Teams.CHOCO, 0, {
              value: parseUnits("1", "ether"),
            })
          ).to.emit(foMoXD, "onEthAirdrop");
        });

        it("Should emit an event on NFT airdrop", async function () {
          const { foMoXD, player1, mockedNumOracle, foMoERC721 } =
            await loadFixture(deployFoMoFixture);
          await mockedNumOracle.mock.isAirdropNfts.returns(true);
          await foMoXD.activate();
          await expect(
            foMoXD.connect(player1).buyXid(Teams.CHOCO, 0, {
              value: parseUnits("1", "ether"),
            })
          ).to.emit(foMoXD, "onNftAirdrop");
          const nftOwnedByUser = await foMoERC721.balance(player1.address);
          await expect(nftOwnedByUser).to.equal(1);
        });
      });
    });

    // describe("Transfers", function () {
    //   it("Should transfer the funds to the owner", async function () {});
    // });
  });

  describe("Affiliate", function () {
    describe("States", function () {
      it("Should be able to register name", async function () {
        const { foMoXD, player1 } = await loadFixture(deployFoMoFixture);
        const nameToRegister = "imTestName".toLocaleLowerCase();
        const registerNameTx = await foMoXD
          .connect(player1)
          .registerNameXID(nameToRegister, 0, true, {
            value: parseUnits("1", "ether"),
          });

        const pID = await foMoXD.playerIDxAddr_(player1.address);
        const bytesName = ethers.utils.formatBytes32String(nameToRegister);

        const pIDGetByName = await foMoXD.pIDxName_(bytesName);
        const isPlayerHasName = await foMoXD.plyrNames_(pID, bytesName);

        expect(registerNameTx).to.emit(foMoXD, "onNewName");
        expect(pIDGetByName).to.equal(pID);
        expect(isPlayerHasName).to.equal(true);
      });

      it("Should change player affiliate ID when buy with buyXname", async function () {
        const { foMoXD, player1, player2, player3, snapshot } =
          await loadFixture(deployFoMoFixture);
        const affName = "imTestName".toLocaleLowerCase();
        const bytesName = ethers.utils.formatBytes32String(affName);
        const affName2 = "imTestName2".toLocaleLowerCase();
        const bytesName2 = ethers.utils.formatBytes32String(affName2);

        await foMoXD.connect(player1).registerNameXID(affName, 0, true, {
          value: parseUnits("1", "ether"),
        });
        await foMoXD.connect(player2).registerNameXID(affName2, 0, true, {
          value: parseUnits("1", "ether"),
        });

        await foMoXD.activate();

        const depositETHAmount = parseUnits("2", "gwei");
        await foMoXD.connect(player3).buyXname(Teams.CHOCO, bytesName, {
          value: depositETHAmount,
        });
        let { player_ } = await snapshot.getPlayerSnapshot(1, 4);
        expect(player_.lastAffiliateId).to.equal(2);

        await foMoXD.connect(player3).buyXname(Teams.CHOCO, bytesName2, {
          value: depositETHAmount,
        });

        ({ player_ } = await snapshot.getPlayerSnapshot(1, 4));
        expect(player_.lastAffiliateId).to.equal(3);
      });

      it("Should change player affiliate ID when buy with buyXid", async function () {
        const { foMoXD, player1, player2, player3, snapshot } =
          await loadFixture(deployFoMoFixture);

        await foMoXD.activate();

        await foMoXD.connect(player1).buyXid(0, 0, {
          value: parseUnits("1", "ether"),
        });
        await foMoXD.connect(player2).buyXid(0, 0, {
          value: parseUnits("1", "ether"),
        });

        const depositETHAmount = parseUnits("2", "gwei");
        await foMoXD.connect(player3).buyXid(Teams.CHOCO, 2, {
          value: depositETHAmount,
        });
        let { player_ } = await snapshot.getPlayerSnapshot(1, 4);
        expect(player_.lastAffiliateId).to.equal(2);

        await foMoXD.connect(player3).buyXid(Teams.CHOCO, 3, {
          value: depositETHAmount,
        });
        ({ player_ } = await snapshot.getPlayerSnapshot(1, 4));
        expect(player_.lastAffiliateId).to.equal(3);
      });

      it("Should change player affiliate ID when buy with buyPuffXAddr", async function () {
        const { foMoXD, player1, player2, player3, snapshot } =
          await loadFixture(deployFoMoFixture);

        await foMoXD.activate();

        await foMoXD.connect(player1).buyXid(0, 0, {
          value: parseUnits("1", "ether"),
        });
        await foMoXD.connect(player2).buyXid(0, 0, {
          value: parseUnits("1", "ether"),
        });

        const depositETHAmount = parseUnits("2", "gwei");

        await foMoXD
          .connect(player3)
          .buyPuffXAddr(Teams.CHOCO, player1.address, {
            value: depositETHAmount,
          });

        const player3Id = await foMoXD.playerIDxAddr_(player3.address);
        let { player_ } = await snapshot.getPlayerSnapshot(1, +player3Id);

        expect(player_.lastAffiliateId).to.equal(2);

        await foMoXD
          .connect(player3)
          .buyPuffXAddr(Teams.CHOCO, player2.address, {
            value: depositETHAmount,
          });

        ({ player_ } = await snapshot.getPlayerSnapshot(1, +player3Id));
        expect(player_.lastAffiliateId).to.equal(3);
      });

      it("Affiliate should get reward", async function () {
        const { foMoXD, player1, player2, player3, snapshot } =
          await loadFixture(deployFoMoFixture);

        await foMoXD.activate();

        const affName = "imTestName".toLocaleLowerCase();
        const affName2 = "imTestName2".toLocaleLowerCase();

        await foMoXD.connect(player1).registerNameXID(affName, 0, true, {
          value: parseUnits("1", "ether"),
        });

        await foMoXD.connect(player2).registerNameXID(affName2, 0, true, {
          value: parseUnits("1", "ether"),
        });

        const depositETHAmount = parseUnits("2", "gwei");

        await foMoXD.connect(player3).buyXid(Teams.CHOCO, 2, {
          value: depositETHAmount,
        });

        let { player_ } = await snapshot.getPlayerSnapshot(1, 4);

        expect(player_.lastAffiliateId).to.equal(2);

        ({ player_ } = await snapshot.getPlayerSnapshot(1, 2));
        expect(player_.affiliateVault).to.gte(0);

        await foMoXD.connect(player3).buyXid(Teams.CHOCO, 3, {
          value: depositETHAmount,
        });

        ({ player_ } = await snapshot.getPlayerSnapshot(1, 3));
        expect(player_.affiliateVault).to.gte(0);

        ({ player_ } = await snapshot.getPlayerSnapshot(1, 4));
        expect(player_.lastAffiliateId).to.equal(3);
      });
    });

    describe("Events", function () {
      it("Should change player affiliate ID when buy with buyXname", async function () {
        const { foMoXD, player1, player3, snapshot } = await loadFixture(
          deployFoMoFixture
        );
        const affName = "imTestName".toLocaleLowerCase();
        const bytesName = ethers.utils.formatBytes32String(affName);

        await foMoXD.connect(player1).registerNameXID(affName, 0, true, {
          value: parseUnits("1", "ether"),
        });

        await foMoXD.activate();

        const depositETHAmount = parseUnits("2", "gwei");

        const buyTx = await foMoXD
          .connect(player3)
          .buyXname(Teams.CHOCO, bytesName, {
            value: depositETHAmount,
          });

        expect(buyTx).to.emit(foMoXD, "onAffiliatePayout");
      });

      it("Should change player affiliate ID when buy with buyXid", async function () {
        const { foMoXD, player1, player2, player3, snapshot } =
          await loadFixture(deployFoMoFixture);

        await foMoXD.activate();

        await foMoXD.connect(player1).buyXid(0, 0, {
          value: parseUnits("1", "ether"),
        });

        const depositETHAmount = parseUnits("2", "gwei");
        const buyTx = await foMoXD.connect(player3).buyXid(Teams.CHOCO, 2, {
          value: depositETHAmount,
        });

        expect(buyTx).to.emit(foMoXD, "onAffiliatePayout");
      });

      it("Should change player affiliate ID when buy with buyPuffXAddr", async function () {
        const { foMoXD, player1, player2, player3, snapshot } =
          await loadFixture(deployFoMoFixture);

        await foMoXD.activate();

        await foMoXD.connect(player1).buyXid(0, 0, {
          value: parseUnits("1", "ether"),
        });

        const depositETHAmount = parseUnits("2", "gwei");

        const buyTx = await foMoXD
          .connect(player3)
          .buyPuffXAddr(Teams.CHOCO, player1.address, {
            value: depositETHAmount,
          });
        expect(buyTx).to.emit(foMoXD, "onAffiliatePayout");
      });
    });
  });

  describe("Withdraw", function () {
    describe("States", function () {
      it("Should transfer ETH to player and update mask", async function () {
        const { foMoXD, player1, snapshot } = await loadFixture(
          deployFoMoFixture
        );
        await foMoXD.activate();
        /* ------------------------ Puffs ----------------------- */
        const depositETHAmount = parseUnits("1", "ether");
        await foMoXD.connect(player1).buyXid(Teams.CHOCO, 0, {
          value: depositETHAmount,
        });
        let {
          player_: player_XWithdraw,
          playerRoundsData_: playerRoundsData__XWithdraw,
        } = await snapshot.getPlayerSnapshot(1, 2);
        await foMoXD.connect(player1).withdraw();
        let { eth, puffs, mask } = playerRoundsData__XWithdraw;
        expect(eth).to.equal(depositETHAmount);
        expect(mask).to.equal(0);
        expect(() => foMoXD.connect(player1).withdraw()).to.changeEtherBalance(
          player1,
          mask
        );
        let {
          player_: player_HasWithdraw,
          playerRoundsData_: playerRoundsData_HasWithdraw,
        } = await snapshot.getPlayerSnapshot(1, 2);
        ({ eth, puffs, mask } = playerRoundsData_HasWithdraw);
        expect(eth).to.equal(depositETHAmount);
        expect(mask).to.gte(0);
        expect(mask).to.lte(depositETHAmount);
      });
    });

    // describe("Validations", function () {});
    describe("Events", function () {
      it("Should emit an event on withdrawals", async function () {
        const { foMoXD, player1, snapshot } = await loadFixture(
          deployFoMoFixture
        );
        await foMoXD.activate();
        const depositETHAmount = parseUnits("1", "ether");
        await foMoXD.connect(player1).buyXid(Teams.CHOCO, 0, {
          value: depositETHAmount,
        });
        await expect(foMoXD.withdraw()).to.emit(foMoXD, "onWithdraw");
      });
    });
    // describe("Transfers", function () {
    //   it("Should transfer the funds to the owner", async function () {});
    // });
  });

  describe("FoMoERC721", function () {
    it("Should be unrevealed when deploy", async function () {
      const { foMoERC721 } = await loadFixture(deployFoMoFixture);
      let counter = 5;
      while (counter > 0) {
        const isRevealed = await foMoERC721.roundIsReveal_(counter);
        expect(isRevealed).to.equal(false);
        counter--;
      }
    });

    it("Should return mystery box URI, before reveal", async function () {
      const { foMoERC721, foMoXD, owner } = await loadFixture(
        deployFoMoFixture
      );

      let roundId = 1;
      while (roundId < 5) {
        const roundBaseURI = `${roundId}_BASE_URI/`;
        const roundMysteryBaseURI = `${roundId}_MYSTERI_URI/`;

        await foMoERC721.setNftRoundBaseURI(roundId, roundBaseURI);
        await foMoERC721.setMysteryTokenURI(roundMysteryBaseURI);
        const mysteryURI = await foMoERC721.mysteryTokenURI_();
        expect(mysteryURI).to.equal(roundMysteryBaseURI);

        await foMoERC721.foMoXDMint(owner.address, 1);
        const balance = await foMoERC721.balance(owner.address);
        let isRounReveal = await foMoERC721.roundIsReveal_(roundId);
        expect(isRounReveal).to.equal(false);
        expect(balance).to.equal(roundId);

        let tokenOneURI = await foMoERC721.getRoundTokenURI(
          roundId,
          roundId - 1
        );

        expect(tokenOneURI).to.equal(mysteryURI);
        await foMoERC721.toggleRoundReveal(roundId);
        const tokenId = roundId - 1;
        tokenOneURI = await foMoERC721.getRoundTokenURI(roundId, tokenId);

        isRounReveal = await foMoERC721.roundIsReveal_(roundId);
        expect(isRounReveal).to.equal(true);
        expect(tokenOneURI).to.equal(roundBaseURI + (+tokenId + 1) + ".json");
        roundId++;
      }
    });

    it("Should reveal when game end", async function () {});
  });
});
