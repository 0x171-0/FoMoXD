import React, { useEffect, useRef, useState, useReducer } from 'react';
import { useWeb3 } from '../../../contexts/providers';
import BaseInput from '../BaseInput';
import './Tabs.css';
import Swal from 'sweetalert2';
import Web3 from 'web3';
import { useSound } from '../../../contexts/sound/Sound';
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
const Tabs = (props: any) => {
  const { fomoXdContract } = useWeb3();
  const {
    playerData,
    roundId,
    roundData,
    setWantXPuffs,
    wantXPuffs,
    puffsToETH,
    setPuffsToETH,
    withdraw,
    buyName,
    params
  } = props;
  const soundContext = useSound();
  // if (!fomoXdContract) {
  //   Toast.fire({
  //     icon: 'error',
  //     title: `🦊 Fail to load web3. Please reload.`
  //   });
  // }
  const [activeTabIndex, setActiveTabIndex] = useState(1);

  const handleTabClick = (index: number) => {
    setActiveTabIndex(index);
    soundContext.clickSound2.play();
  };
  const checkActive = (index: number, className: string) =>
    activeTabIndex === index ? className : '';

  async function updatePuffsAndETH(puffs: number) {
    setWantXPuffs(puffs);
    const eth = await fomoXdContract?.methods
      ?.iWantXPuffs(Web3.utils.toWei(puffs.toString(), 'ether'))
      .call();
    setPuffsToETH(Web3.utils.fromWei(eth.toString(), 'ether'));
  }

  return (
    <div className="tabs-wrapper">
      <div className="tabs-container">
        <div className="tabs">
          <button className={`tab ${checkActive(1, 'active')}`} onClick={() => handleTabClick(1)}>
            Puff
          </button>
          <button className={`tab ${checkActive(2, 'active')}`} onClick={() => handleTabClick(2)}>
            Vault
          </button>
          <button className={`tab ${checkActive(3, 'active')}`} onClick={() => handleTabClick(3)}>
            Round
          </button>
          <button className={`tab ${checkActive(4, 'active')}`} onClick={() => handleTabClick(4)}>
            Referrals
          </button>
        </div>
        <div className="panels">
          <div className={`panel ${checkActive(1, 'active')}`}>
            <p>roundId:{roundId}</p>
            <p>
              Purchases of .1 ETH or more have a 1% chance to win some of the airdrop pot & NFT,
              instantly!
            </p>
            <div className="input-group">
              <div className="input-group-text">
                <span>🧁/ETH</span>
                {/* <i className="fas fa-key fa-lg" aria-hidden="true"></i> */}
              </div>
              <input
                aria-label="First name"
                type="number"
                id="keys-field"
                className="form-control"
                value={Number(wantXPuffs) || 0}
                onChange={async (e: any) => {
                  soundContext.coinSound.play();
                  updatePuffsAndETH(e.target.value);
                }}
              />
              <input
                value={puffsToETH || 0}
                aria-label="Last name"
                className="form-control"
                disabled={true}
                onClick={(e: any) => {
                  soundContext.coinSound.play();
                  updatePuffsAndETH(Number(wantXPuffs) + 100);
                }}
              />
            </div>
            <div role="group" className="increment-keys-buttons btn-group">
              <button
                type="button"
                className="btn btn-outline-warning"
                onClick={async (e: any) => {
                  soundContext.coinSound.play();
                  updatePuffsAndETH(Number(wantXPuffs) + 1);
                }}>
                + 1 Puff
              </button>
              <button
                type="button"
                className="btn btn-outline-warning"
                onClick={async (e: any) => {
                  soundContext.coinSound.play();
                  updatePuffsAndETH(Number(wantXPuffs) + 2);
                }}>
                + 2 Puffs
              </button>
              <button
                type="button"
                className="increment-button btn btn-outline-warning"
                onClick={async (e: any) => {
                  soundContext.coinSound.play();
                  updatePuffsAndETH(Number(wantXPuffs) + 5);
                }}>
                <div>+</div>5
              </button>
              <button
                type="button"
                className="increment-button btn btn-outline-warning"
                onClick={async (e: any) => {
                  soundContext.coinSound.play();
                  updatePuffsAndETH(Number(wantXPuffs) + 10);
                }}>
                <div>+</div>10
              </button>
              <button
                type="button"
                className="increment-button btn btn-outline-warning"
                onClick={(e: any) => {
                  soundContext.coinSound.play();
                  updatePuffsAndETH(Number(wantXPuffs) + 100);
                }}>
                <div>+</div>100
              </button>
            </div>
          </div>
          <div className={`panel ${checkActive(2, 'active')}`}>
            <div className="from-inputs">
              {/* 獎金收益 - final pot + air drop  On Lockdown*/}
              <BaseInput
                label="exit"
                text="Winning"
                value={Web3.utils.fromWei(playerData.winningVault.toString(), 'ether')}
                type="string"
              />
              {/* 普通收益 Exit Scammed*/}
              <BaseInput
                label="exit"
                text="General"
                value={Web3.utils.fromWei(playerData.generalVault.toString(), 'ether')}
                type="string"
              />
              {/* 推薦獎勵 */}
              {
                <BaseInput
                  label="exit"
                  text="Bad Advice"
                  value={Web3.utils.fromWei(playerData.affiliateVault.toString(), 'ether')}
                  type="string"
                />
              }
              {/* 總收益 */}
              <BaseInput
                label="gan"
                text="Total Vault"
                value={Web3.utils.fromWei(
                  (+playerData.generalVault + +playerData.winningVault).toString(),
                  'ether'
                )}
                type="string"
              />
              <div className="tab-button-wrapper">
                <button
                  className="tab-button btn"
                  onClick={async () => {
                    await withdraw();
                  }}>
                  Withdraw
                </button>
              </div>
            </div>
          </div>
          <div className={`panel ${checkActive(3, 'active')}`}>
            <div className="from-inputs">
              <BaseInput
                label="pot"
                text="Total Pot"
                value={Web3.utils.fromWei(roundData.pot.toString(), 'ether')}
                type="string"
              />
              <BaseInput
                label="puffs"
                text="Total Puffs"
                value={Web3.utils.fromWei(roundData.puffs.toString(), 'ether')}
                type="string"
              />
              <BaseInput
                label="round-gans"
                text="Total Gains"
                value={Web3.utils.fromWei(roundData.mask.toString(), 'ether')}
                type="string"
              />
              <BaseInput
                label="your-puffs"
                text="Your Puffs"
                value={Web3.utils.fromWei(playerData.puffs.toString(), 'ether')}
                type="string"
              />
              <BaseInput
                label="your-gans"
                text="Your Gains"
                value={Web3.utils.fromWei(playerData.mask.toString(), 'ether')}
                type="string"
              />
            </div>
          </div>
          <div className={`panel ${checkActive(4, 'active')}`}>
            <div className="from-inputs">
              {playerData?.playerNames?.length === 0
                ? ''
                : playerData?.playerNames?.map((name: string) => {
                    return (
                      <div className="from-input">
                        <label htmlFor={name}>{name}</label>
                      </div>
                    );
                  })}
              <button
                className="tab-button btn"
                onClick={async () => {
                  const { value: name } = await Swal.fire({
                    title: 'Enter your referel name',
                    input: 'text',
                    inputLabel: 'Please type in low letter',
                    inputValue: '',
                    showCancelButton: true,
                    inputValidator: async (value: string) => {
                      if (!value) {
                        return 'You need to write something!';
                      } else {
                        return await buyName(value, params);
                      }
                    }
                  });
                }}>
                Buy referel name
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Tabs;
