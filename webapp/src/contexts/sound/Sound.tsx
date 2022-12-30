import { useContext, useEffect, useRef, useState, useReducer, createContext, useMemo } from 'react';
import { ReactSoundProps } from 'react-sound';
const { REACT_APP_STATIC_URL } = process.env;

export const SoundContext = createContext({
  isPlaying: true,
  setIsPlaying: (newState: boolean) => {},
  clickSound: new Audio(REACT_APP_STATIC_URL + '/sounds/car_trunk_O.mp3'),
  clickSound2: new Audio(REACT_APP_STATIC_URL + '/sounds/mobile_phone_C.mp3'),
  clickSound3: new Audio(REACT_APP_STATIC_URL + '/sounds/mobile_phone_O.mp3'),
  coinSound: new Audio(REACT_APP_STATIC_URL + '/sounds/coin.wav')
});
const isMute = localStorage.getItem('isMute') ? true : false;

export default function SoundProvider(props: any) {
  // @ts-ignore
  window.soundManager.setup({ debugMode: false });
  const { children } = props;
  const [isPlaying, setIsPlaying] = useState<boolean>(!isMute);
  const value = {
    isPlaying,
    setIsPlaying,
    clickSound: new Audio(REACT_APP_STATIC_URL + '/sounds/car_trunk_O.mp3'),
    clickSound2: new Audio(REACT_APP_STATIC_URL + '/sounds/mobile_phone_C.mp3'),
    clickSound3: new Audio(REACT_APP_STATIC_URL + '/sounds/mobile_phone_O.mp3'),
    coinSound: new Audio(REACT_APP_STATIC_URL + '/sounds/coin.wav')
  };
  return <SoundContext.Provider value={value}>{children}</SoundContext.Provider>;
}

export function useSound() {
  return useContext(SoundContext);
}
