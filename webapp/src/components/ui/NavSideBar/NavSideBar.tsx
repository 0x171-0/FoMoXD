import { Fragment, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { NavSideBarDiv } from './style';
import Swal from 'sweetalert2';
import { useSound } from '../../../contexts/sound/Sound';
// Hooks
import { useWeb3 } from '../../../contexts/providers';
import { useGameData } from '../../../contexts/gameData/GameData';
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
const NavSideBar = (props: any) => {
  const { connect, switchNetwork, fomoXdContract, foMoERC721, account, disconnect } = useWeb3();
  const { roundId, endTime, setRoundId, fetchNewRound } = useGameData();
  const soundContext = useSound();

  const [connected, setConnected] = useState(true);

  const onClickSoundHandler = (e: React.MouseEvent) => {
    soundContext.setIsPlaying(!soundContext.isPlaying);
    if (localStorage.getItem('isMute')) {
      localStorage.removeItem('isMute');
    } else {
      localStorage.setItem('isMute', 'true');
    }
    Toast.fire({
      icon: 'success',
      title: `${!soundContext.isPlaying ? '🎉 Party Time' : '🤫 Shh...'}`
    });
  };

  const onClickPickRoundHandler = async (e: React.MouseEvent) => {
    soundContext.clickSound.play();
    const newRoundId = await fomoXdContract?.methods?.roundID_().call();
    let index = newRoundId as number;
    const inputOptions: any = {};
    while (index > 0) {
      inputOptions[index.toString()] = index;
      index--;
    }
    const { value: roundSelected } = await Swal.fire({
      title: 'Select a round',
      input: 'select',
      inputOptions: inputOptions,
      inputPlaceholder: 'Select a round',
      showCancelButton: true,
      inputValue: roundId
      // inputValidator: (value) => {
      //   return new Promise((resolve) => {
      //     if (value === 'oranges') {
      //       resolve();
      //     } else {
      //       resolve('You need to select oranges :)');
      //     }
      //   });
      // }
    });

    if (roundSelected) {
      Toast.fire({
        icon: 'success',
        title: `🎯 You are now at: ${roundSelected}`
      });
      setRoundId(roundSelected);
      fetchNewRound(roundSelected);
    }
  };

  const onClickMetaMaskHandler = (e: React.MouseEvent) => {
    soundContext.clickSound.play();
    if (connected) {
      disconnect();
    } else {
      connect();
      switchNetwork();
    }
    setConnected(!connected);
  };

  return (
    <Fragment>
      <NavSideBarDiv>
        <div className="nav-side-title-wrapper">
          <Link
            className="nav-side-title-icon"
            style={{ textDecoration: 'none' }}
            to="/"
            onClick={(e: React.MouseEvent) => {
              soundContext.clickSound.play();
            }}>
            <span>🧁 </span>
            <span> FomoXD </span>
          </Link>
          <div className="message">
            <span>
              {account
                ? `ROUND ${roundId} END AT: ${new Date(endTime).toLocaleTimeString()}`
                : 'You are not connected...'}
            </span>
          </div>
          <div className="nav-bar">
            <Link
              style={{ textDecoration: 'none' }}
              className="nav-bar-icon"
              to="/nfts"
              onClick={(e: React.MouseEvent) => {
                soundContext.clickSound.play();
                Toast.fire({
                  icon: 'success',
                  title: `🖼️ Here is your NFTs`
                });
              }}>
              <h5>🖼️</h5>
            </Link>
            <Link
              style={{ textDecoration: 'none' }}
              className="nav-bar-icon"
              to="/exit-scam"
              onClick={onClickPickRoundHandler}>
              <h5>🎰</h5>
            </Link>
            <Link
              style={{ textDecoration: 'none' }}
              className="nav-bar-icon"
              to="/exit-scam"
              onClick={onClickMetaMaskHandler}>
              <h5>{connected && fomoXdContract ? '🦊' : '🫥'}</h5>
            </Link>
            <div
              style={{ textDecoration: 'none' }}
              className="nav-bar-icon"
              onClick={onClickSoundHandler}>
              <h5>{soundContext.isPlaying ? '🔊' : '🔇'}</h5>
            </div>
          </div>
        </div>
      </NavSideBarDiv>
    </Fragment>
  );
};
export default NavSideBar;
