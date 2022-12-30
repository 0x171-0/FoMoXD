import React from 'react';
import useSWR from 'swr';
import Swal from 'sweetalert2';

const targetNetwork = 31337; // Hardhat Tesnet
// const targetNetwork = 1337; // Ganache

const { REACT_APP_GOERLI_CHAIN_ID } = process.env;
export const handler = (web3: any, provider: any) => () => {
  const { data, mutate, ...rest } = useSWR(
    () => (web3 ? 'web3/network' : null),
    async () => {
      let chainId = await web3.eth.getChainId();
      if (chainId !== 31337) {
        Swal.fire({
          icon: 'info',
          title: 'Wrong network',
          showCancelButton: true,
          confirmButtonText: 'Swich to right one',
          width: 600,
          padding: '3em',
          color: '#716add',
          background: '#fff url("")',
          backdrop: `
            rgba(0,0,123,0.4)
            url("/nyan-cat.gif")
            left top
            no-repeat
          `
        }).then(async (result) => {
          if (result.isConfirmed) {
            Swal.fire('Saved!', '', 'success');
            await provider.request({
              method: 'wallet_switchEthereumChain',
              params: [
                {
                  chainId:
                    '0x' +
                    (parseInt(REACT_APP_GOERLI_CHAIN_ID || '31337', 10) as number).toString(16)
                }
              ]
            });
            chainId = await web3.eth.getChainId();
          } else if (result.isDenied) {
            Swal.fire('Network are not changed', '', 'info');
          }
        });
      }
      if (!chainId) {
        throw new Error('Cannot retreive network. Please refresh the browser.');
      }
      return chainId;
    }
  );

  React.useEffect(() => {
    provider &&
      provider.on('chainChanged', (chainId: string) => {
        mutate(parseInt(chainId, 16));
      });
  }, [mutate]);

  return {
    data,
    mutate,
    target: targetNetwork,
    isSupported: data === targetNetwork,
    ...rest
  };
};
