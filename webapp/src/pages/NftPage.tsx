import { Fragment, useContext, useState, useEffect } from 'react';
import CubeLayout from '../components/layout/CubeLayout/CubeLayout';
import Sound, { ReactSoundProps } from 'react-sound';
import { useSound } from '../contexts/sound/Sound';
import { useGameData } from '../contexts/gameData/GameData';
import { useWeb3 } from '../contexts/providers';
const { REACT_APP_STATIC_URL } = process.env;

const NftsPage = () => {
  const soundContext = useSound();
  const { foMoERC721 } = useWeb3();
  const game = useGameData();
  const { playerData } = game;
  const [nftsMeta, setNftMetas] = useState<{}[]>(playerData.nfts);
  useEffect(() => {
    const timer = setInterval(async () => {
      const jsonNfts = [];
      if (playerData?.nfts?.length > 0) {
        for (const nft of playerData?.nfts) {
          const { tokenId, roundId } = nft;
          const meta = (await foMoERC721.methods
            .getRoundTokenURI(roundId, tokenId)
            .call()) as string;
          const fetchData = await fetch(meta);
          const res = (await fetchData?.json()) as { image: string };
          jsonNfts.push({
            ...res,
            url: res.image
          });
        }
        setNftMetas(jsonNfts);
      }
      return () => clearInterval(timer);
    }, 1000);
  }, [playerData.nfts]);

  return (
    <Fragment>
      <Sound
        url={REACT_APP_STATIC_URL + '/sounds/Jigglypuff.mp3'}
        playStatus={soundContext?.isPlaying ? 'PLAYING' : 'STOPPED'}
        loop={true}
        autoLoad={true}
        volume={30}
      />
      ;<CubeLayout items={nftsMeta} title={'PUFFS NFTS'}></CubeLayout>;
    </Fragment>
  );
};
export default NftsPage;
