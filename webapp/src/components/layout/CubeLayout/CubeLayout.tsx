import { useState } from 'react';
import CubeNft from '../../ui/CubeNft/CubeNft';
import PageHeader from '../../ui/PageHeader/PageHeader';
import { MainNft } from '../../ui/CubeNft/style';
import DetailBoard from '../../ui/DetailBoard/DetailBoard';

const CubeLayout = (props: any) => {
  const noDevices = <p>Not devices</p>;
  const [devices, setDevices] = useState(props.items);
  return (
    <div className="App">
      <div className="App-body">
        <div className="App-page-body">
          <PageHeader title={props.title}></PageHeader>
          <MainNft url={devices[0].url}>
            <img></img>
            <div>
              <h6>#17 CHOCHOLATE PUFF</h6>
              <p>Last sale: 5 ETH</p>
            </div>
          </MainNft>
          <div className="cube-wrapper">
            {devices.length === 0 && noDevices}
            {devices.length > 0 &&
              devices.map((info: any, index: number) => {
                if (index === 0) return;
                return <CubeNft info={info} key={info.id}></CubeNft>;
              })}
          </div>
        </div>
      </div>
    </div>
  );
};

export default CubeLayout;
