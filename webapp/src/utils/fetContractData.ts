import Swal from 'sweetalert2';
import Web3Lib from 'web3';
export const TeamsArr = ['🍫 ', '🍌 ', '🍓 ', '🥝 '];
const { REACT_APP_STATIC_URL } = process.env;

const Toast = Swal.mixin({
  toast: true,
  position: 'bottom-end',
  showConfirmButton: false,
  timer: 3000,
  timerProgressBar: true,
  didOpen: (toast) => {
    toast.addEventListener('mouseenter', Swal.stopTimer);
    toast.addEventListener('mouseleave', Swal.resumeTimer);
  }
});

export default class GameHelper {
  fomoXdContract: any;
  foMoERC721: any;
  web3: any;
  account: any;
  setPlayerData: any;
  setEndTime: any;
  setRoundData: any;
  eventsListeners: any = [];
  roundId: number;
  playerId: number = 0;

  constructor(opt: {
    fomoXdContract: any;
    foMoERC721: any;
    web3: any;
    account: any;
    setPlayerData: any;
    setEndTime: any;
    setRoundData: any;
    roundId: number;
  }) {
    const {
      fomoXdContract,
      foMoERC721,
      web3,
      account,
      setPlayerData,
      setEndTime,
      setRoundData,
      roundId
    } = opt;
    this.fomoXdContract = fomoXdContract;
    this.web3 = web3;
    this.account = account;
    this.setPlayerData = setPlayerData;
    this.setEndTime = setEndTime;
    this.setRoundData = setRoundData;
    this.foMoERC721 = foMoERC721;
    this.roundId = roundId;
  }
  async buyPuffs(opt: {
    activeTeamIndex: number;
    puffsToETH: number;
    wantXPuffs: any;
    aff?: {
      address?: string;
      name?: string;
      id?: number;
    };
  }) {
    const { wantXPuffs, activeTeamIndex, puffsToETH, aff } = opt;
    new Audio(REACT_APP_STATIC_URL + '/sounds/coin.wav').play();

    if (wantXPuffs <= 0 || puffsToETH <= 0) {
      Toast.fire({
        icon: 'error',
        title: `🧁 Please add up puffs.`
      });
    } else if (!activeTeamIndex) {
      Toast.fire({
        icon: 'error',
        title: `🎯 Please select teams.`
      });
    } else {
      // pay ${Number(puffsToETH).toFixed(6)}
      Swal.fire({
        title: `Sure to to buy for ${wantXPuffs} puffs in ${
          TeamsArr[activeTeamIndex - 1 > 0 ? activeTeamIndex - 1 : 0]
        }team?`,
        showCancelButton: true,
        confirmButtonText: 'Give me puffs',
        cancelButtonText: 'Exit Scam',
        padding: '3em',
        color: '#716add',
        text: 'Make Sure You See This Cute Pic.',
        imageUrl: 'https://media.giphy.com/media/Ga1uKRbTv1lABGqBtv/giphy.gif',
        imageWidth: 350,
        imageAlt: 'Custom image',
        backdrop: `
            rgba(0,0,123,0.4)
            url("/nyan-cat.gif")
            left top
            no-repeat
          `
      }).then(async (result) => {
        if (result.isConfirmed) {
          await this.buyPuff({
            activeTeamIndex,
            puffsToETH,
            aff
          });
        } else {
          Swal.fire({
            title: 'Puffsssss~~~',
            padding: '5em',
            color: '#716add',
            background: '#fff url(https://media.giphy.com/media/UmLKVhZSLBQmk/giphy.gif)',
            showConfirmButton: false,
            timer: 2500,
            backdrop: `
            rgba(0,0,123,0.4)
            url("/nyan-cat.gif")
            left top
            no-repeat
          `
          });
        }
      });
    }
  }

  async buyName(name: string, aff?: { address?: string; name?: string; id?: number }) {
    const affcode = aff?.id || 0;
    await this.fomoXdContract.methods
      ?.registerNameXID(name.trim(), affcode, true)
      .send({ from: this.account, value: this.web3.utils.toWei('1', 'gwei') })
      .then((receipt: any) => {
        Swal.fire({
          title: `You have new name!`,
          confirmButtonText: 'OK',
          padding: '3em',
          color: '#716add',
          text: `Now giving people bad advices to earn more`,
          imageUrl: 'https://media.giphy.com/media/r95kAgBEzeapljl1ft/giphy.gif',
          imageWidth: 350,
          imageAlt: 'Custom image',
          backdrop: `
            rgba(0,0,123,0.4)
            url("/nyan-cat.gif")
            left top
            no-repeat
          `
        }).then(async (result) => {
          if (result.isConfirmed) {
            window.location.reload();
          }
        });
      })
      .catch((e: any) => {
        console.error(e);
        Toast.fire({
          icon: 'error',
          title: `😭 Fail to Buy Name.`
        });
      });
  }

  async buyPuff(opt: {
    activeTeamIndex: number;
    puffsToETH: number;
    aff?: { address?: string; name?: string; id?: number };
  }) {
    const { activeTeamIndex, puffsToETH, aff } = opt;
    let buyX;
    if (aff?.id) {
      buyX = this.fomoXdContract.methods?.buyXid(activeTeamIndex - 1, aff?.id);
    } else if (aff?.address) {
      buyX = this.fomoXdContract.methods?.buyPuffXAddr(activeTeamIndex - 1, aff?.address);
    } else if (aff?.name) {
      buyX = this.fomoXdContract.methods?.buyXname(
        activeTeamIndex - 1,
        Web3Lib.utils.asciiToHex(aff?.name)
      );
    } else {
      buyX = this.fomoXdContract.methods?.buyXid(activeTeamIndex - 1, 0);
    }

    await buyX
      .send({ from: this.account, value: this.web3.utils.toWei(puffsToETH, 'ether') })
      .then((receipt: any) => {
        if (receipt?.events?.onNftAirdrop) {
          Swal.fire({
            title: `You Got an NFT Air Drop!`,
            showCancelButton: true,
            confirmButtonText: 'Go',
            cancelButtonText: 'No thx.',
            padding: '3em',
            color: '#716add',
            text: 'You Got an NFT',
            imageUrl: 'https://media.giphy.com/media/dvBgr7pA6FTJOMOALY/giphy.gif',
            imageWidth: 350,
            imageAlt: 'Custom image',
            backdrop: `
            rgba(0,0,123,0.4)
            url("/nyan-cat.gif")
            left top
            no-repeat
          `
          }).then(async (result) => {
            if (result.isConfirmed) {
              window.location.pathname = '/nfts';
            } else {
              await this.fetchNewRound(this.roundId);
            }
          });
        }
        if (receipt?.events?.onEthAirdrop) {
          Swal.fire({
            title: 'Moon~~~',
            padding: '5em',
            color: '#716add',
            background:
              '#fff url(https://media.giphy.com/media/3o6Zt6JnZK8AU2qi9W/giphy-downsized-large.gif)',
            showConfirmButton: false,
            timer: 2500,
            backdrop: ` rgba(0,0,123,0.4) url("/nyan-cat.gif") left top no-repeat`
          });
        }
      })
      .catch((e: any) => {
        console.error(e);
        Toast.fire({
          icon: 'error',
          title: `🧁 Fail to Buy Puffs.`
        });
      });
  }

  async withdraw() {
    await this.fomoXdContract.methods
      ?.withdraw()
      .send({ from: this.account })
      .then(async (receipt: any) => {
        Toast.fire({
          icon: 'success',
          title: `💰 Success to withdraw ${Web3Lib.utils.fromWei(
            receipt?.events?.onWithdraw?.returnValues?.ethOut,
            'ether'
          )} ETH.`
        });
        await this.fetchNewRound(this.roundId);
      })
      .catch((e: any) => {
        console.error(e);
        Toast.fire({
          icon: 'error',
          title: `🤡 Fail to withdraw.`
        });
      });
  }

  async fetchPlayerRoundData(_roundId: number) {
    this.playerId = await this.fomoXdContract?.methods?.playerIDxAddr_(this.account).call();
    const newPlayerData = await this.fomoXdContract?.methods?.player_(this.playerId).call();
    const newPlayerRoundData = await this.fomoXdContract?.methods
      ?.playerRoundsData_(this.playerId, _roundId)
      .call();

    this.fomoXdContract
      .getPastEvents('onNftAirdrop', {
        filter: { playerAddr: this.account },
        fromBlock: 0,
        toBlock: 'latest'
      })
      .then(async (events: any) => {
        const lastNfts = [];
        for (const e of events) {
          const nowRoundId = e?.returnValues?.roundId;
          lastNfts.push(
            ...e?.returnValues?.tokenIds.map((e: number) => {
              return { tokenId: e, roundId: nowRoundId };
            })
          );
          this.setPlayerData({ ...newPlayerRoundData, ...newPlayerData, nfts: lastNfts });
        }
      });
    this.setPlayerData({ ...newPlayerRoundData, ...newPlayerData });
    return this.playerId;
  }

  async fetchNewRound(_roundId: number) {
    const r = await this.fomoXdContract?.methods?.roundData_(_roundId).call();
    const playerId = await this.fetchPlayerRoundData(_roundId);
    this.setRoundData({ ...r, isWinner: playerId === r.winnerId });
    this.setEndTime(r.endTime * 1000);
  }

  async initEventListener() {
    this.eventsListeners.forEach((element: any) => {
      element.stopWatching();
    });
    const allEvents = this.fomoXdContract.events
      .allEvents({
        // filter: {
        //   from: [
        //   ]
        // }
      })
      .on('data', async (event: any) => {
        console.log('✅ New Events!', this.roundId, event);
        // await this.fetchNewRound(this.roundId);
      });

    await this.fomoXdContract
      .getPastEvents('onEndRound', {
        filter: { playerAddr: this.account },
        fromBlock: 0,
        toBlock: 'latest'
      })
      .then(async (events: any) => {
        console.log('✅ onEndRound!', events);
      });

    await this.fomoXdContract
      .getPastEvents('onNewName', {
        filter: { playerAddress: this.account },
        fromBlock: 0,
        toBlock: 'latest'
      })
      .then(async (events: any) => {
        const playerNames: string[] = [];
        for (const e of events) {
          playerNames.push(Web3Lib.utils.toAscii(e.returnValues.playerName));
        }
        this.setPlayerData((last: any) => {
          return { ...last, playerNames };
        });
      });

    const onWithdraw = this.fomoXdContract.events.onWithdraw().on('data', (event: any) => {
      if (event?.returnValues?.playerAddress !== this.account) {
        Toast.fire({
          icon: 'success',
          title: `🤑 PlayerId: ${
            event?.returnValues?.playerID
          } just siphoned ${Web3Lib.utils.fromWei(
            event?.returnValues?.ethOut,
            'ether'
          )} ETH from FoMo.`
        });
      }
    });

    // this.fomoXdContract.events.onAffiliatePayout().on('data', (event: any) => {
    //   if (event?.returnValues?.affiliateAddress == this.account) {
    //     Swal.fire({
    //       title: `Congrats!`,
    //       confirmButtonText: 'OK',
    //       padding: '3em',
    //       color: '#716add',
    //       text: `You won affiliate reward!`,
    //       imageUrl: 'https://media.giphy.com/media/SsTcO55LJDBsI/giphy.gif',
    //       imageWidth: 350,
    //       imageAlt: 'Custom image',
    //       backdrop: `
    //         rgba(0,0,123,0.4)
    //         url("/nyan-cat.gif")
    //         left top
    //         no-repeat
    //       `
    //     }).then(async (result) => {
    //       if (result.isConfirmed) {
    //         window.location.reload();
    //       }
    //     });
    //   }
    // });

    this.fomoXdContract.events.onBuyPuff().on('data', async (event: any) => {
      await this.fetchNewRound(this.roundId);
      if (
        event?.returnValues?.affId == this.playerId &&
        this.playerId !== 0 &&
        event?.returnValues?.affId !== '0'
      ) {
        Swal.fire({
          title: `Congrats!`,
          confirmButtonText: 'OK',
          padding: '3em',
          color: '#716add',
          text: `You won affiliate reward!`,
          imageUrl: 'https://media.giphy.com/media/SsTcO55LJDBsI/giphy.gif',
          imageWidth: 350,
          imageAlt: 'Custom image',
          backdrop: `
            rgba(0,0,123,0.4)
            url("/nyan-cat.gif")
            left top
            no-repeat
          `
        }).then(async (result) => {
          if (result.isConfirmed) {
            await this.fetchNewRound(this.roundId);
          }
        });
      } else if (event?.returnValues?.playerAddress != this.account) {
        Toast.fire({
          icon: 'success',
          title: `🧁 PlayerId: ${event?.returnValues?.playerId} just buy ${Web3Lib.utils.fromWei(
            event?.returnValues?.puffssBought,
            'ether'
          )} Puffs.`
        });
        await this.fetchNewRound(this.roundId);
      }
    });

    const onEndRound = this.fomoXdContract.events.onEndRound().on('data', (event: any) => {
      const { roundId, winnerId, winnerTeamId, endTime, generalShare, winnerShare } =
        event?.returnValues;
      if (winnerId == this.playerId) {
        Swal.fire({
          title: `You won the game!`,
          confirmButtonText: 'OK',
          padding: '3em',
          color: '#716add',
          text: `You won ${Web3Lib.utils.fromWei(winnerShare, 'ether')}`,
          imageUrl: 'https://media.giphy.com/media/RLVHPJJv7jY1q/giphy.gif',
          imageWidth: 350,
          imageAlt: 'Custom image',
          backdrop: `
            rgba(0,0,123,0.4)
            url("/nyan-cat.gif")
            left top
            no-repeat
          `
        }).then(async (result) => {
          if (result.isConfirmed) {
            window.location.reload();
          }
        });
      } else {
        Swal.fire({
          title: `Game Over!`,
          confirmButtonText: 'OK',
          padding: '3em',
          color: '#716add',
          text: `Winner won ${Web3Lib.utils.fromWei(winnerShare, 'ether')}`,
          imageUrl: 'https://media.giphy.com/media/7Uj0tJ6r2CeOs/giphy.gif',
          imageWidth: 350,
          imageAlt: 'Custom image',
          backdrop: `
            rgba(0,0,123,0.4)
            url("/nyan-cat.gif")
            left top
            no-repeat
          `
        }).then(async (result) => {
          if (result.isConfirmed) {
            window.location.reload();
          }
        });
      }
    });
    this.eventsListeners.push(allEvents, onWithdraw, onEndRound);
  }
}
