import { useParams } from 'react-router-dom';
import Cube from '../components/ui/Cube/Cube';
import PageHeader from '../components/ui/PageHeader/PageHeader';
import Tabs from '../components/ui/Tabs/Tabs';
import CountdownTimer from '../components/Timer/Timer';
import Sound, { ReactSoundProps } from 'react-sound';
import Swal from 'sweetalert2';
import { useSound } from '../contexts/sound/Sound';
import { useGameData } from '../contexts/gameData/GameData';
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

const GamesPage = (props: any) => {
  const params = useParams();

  const game = useGameData();
  const {
    endTime,
    roundData,
    setActiveTeamIndex,
    activeTeamIndex,
    buyPuffs,
    wantXPuffs,
    setWantXPuffs,
    puffsToETH,
    setPuffsToETH,
    playerData,
    withdraw,
    roundId,
    buyName
  } = game;
  const soundContext = useSound();

  const teams = JSON.parse(localStorage.getItem('teams') as string);
  const noTeams = <p>Not devices</p>;
  const handleTeamClick = (index: number) => setActiveTeamIndex(index);
  const checkTeamActive = (index: number) => (activeTeamIndex === index ? true : false);

  return (
    <div>
      <div className="App">
        <div className="App-body">
          <div className="App-page-body">
            <Sound
              url={REACT_APP_STATIC_URL + '/sounds/Yes and No at the Same Time - half.cool.mp3'}
              playStatus={soundContext?.isPlaying ? 'PLAYING' : 'STOPPED'}
              loop={true}
              autoLoad={true}
              volume={30}
              onError={() => {
                Toast.fire({
                  icon: 'error',
                  title: `🔊 Fail to load music.`
                });
              }}
            />
            <CountdownTimer
              targetDate={endTime}
              isGameEnd={roundData.ended}
              isWinner={roundData.isWinner}
              winnerId={roundData.winnerId}
              nftsNum={playerData?.nfts?.length}
            />
            <PageHeader
              title={activeTeamIndex ? 'Buy Puffs' : 'CHOOSE YOUR TEAM'}
              isShowBuyButton={activeTeamIndex !== 0}
              activeIndex={activeTeamIndex}
              buyPuffs={() => {
                buyPuffs({ aff: { ...params } });
              }}></PageHeader>
            <div className="cube-wrapper">
              {teams.length === 0 && noTeams}
              {teams.length > 0 &&
                teams.map((info: any, index: number) => {
                  return (
                    <Cube
                      info={info}
                      key={info.id}
                      state={checkTeamActive(index + 1)}
                      onClick={async () => {
                        checkTeamActive(index + 1)
                          ? await soundContext.clickSound3.play()
                          : await soundContext.clickSound2.play();
                        handleTeamClick(index + 1);
                      }}></Cube>
                  );
                })}
            </div>
            <Tabs
              roundId={roundId}
              roundData={roundData}
              playerData={playerData}
              wantXPuffs={wantXPuffs}
              withdraw={withdraw}
              setWantXPuffs={setWantXPuffs}
              puffsToETH={puffsToETH}
              setPuffsToETH={setPuffsToETH}
              buyName={buyName}
              params={params}
            />
          </div>
        </div>
      </div>
    </div>
  );
};

export default GamesPage;
