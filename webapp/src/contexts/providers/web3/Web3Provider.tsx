import { useContext, useEffect, useState, createContext, useMemo } from 'react';
import detectEthereumProvider from '@metamask/detect-provider';
import Swal from 'sweetalert2';
import Web3 from 'web3';
import { setupHooks } from './hooks/setupHooks';
import { loadContractWithAddress } from '../../../utils/loadContract';
const {
  REACT_APP_FOMO_CONTRACT_ADDRESS,
  REACT_APP_RPC_URL,
  REACT_APP_FOMOERC721_CONTRACT_ADDRESS
} = process.env;
const Web3Context = createContext(null);

interface Web3State {
  gameContract?: any;
  foMoERC721?: any;
  web3: any;
  account: string;
  hooks?: any;
  provider: any;
  isLoading: any;
  factoryContract?: any;
  connect?: any;
  switchNetwork?: any;
}

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

const createWeb3State = (props: Web3State) => {
  const { web3, provider, isLoading, gameContract, account, foMoERC721 } = props;
  console.log('foMoERC721💩💩', foMoERC721);
  const result = {
    web3,
    provider,
    gameContract,
    isLoading,
    hooks: setupHooks(web3, provider),
    account,
    foMoERC721
  };
  return result;
};

let lastAcoount = '';
export default function Web3Provider(props: any) {
  const { children } = props;
  const [nowAccount, setAccount] = useState('');
  const [web3Api, setWeb3Api] = useState(
    createWeb3State({
      web3: undefined,
      provider: undefined,
      factoryContract: undefined,
      isLoading: true,
      account: nowAccount,
      gameContract: undefined,
      foMoERC721: undefined
    })
  );

  useEffect(() => {
    let timer: any;
    const loadProvider = async () => {
      const provider =
        ((await detectEthereumProvider()) as any) ||
        new Web3.providers.HttpProvider(REACT_APP_RPC_URL as string);
      const web3 = new Web3(provider);
      const gameContract = await loadContractWithAddress(
        'FoMoXD',
        web3.utils.toChecksumAddress(REACT_APP_FOMO_CONTRACT_ADDRESS as string),
        web3
      );
      const foMoERC721 = await loadContractWithAddress(
        'FoMoERC721',
        web3.utils.toChecksumAddress(REACT_APP_FOMOERC721_CONTRACT_ADDRESS as string),
        web3
      );
      const [newAccount] = await web3.eth.getAccounts();
      setAccount(newAccount);
      lastAcoount = newAccount;
      if (!gameContract || !newAccount?.length || !foMoERC721) {
        Swal.fire({
          title: `What Does the Fox Say?`,
          // showCancelButton: true,
          confirmButtonText: 'Ya~ Done! Wa-pa-pa-pow!',
          // cancelButtonText: 'Exit Scam',
          padding: '3em',
          color: '#716add',
          text: 'Connect with Metamask to start 🦊.',
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
            Swal.fire('Saved!', '', 'success');
            window.location.reload();
          } else if (result.isDenied) {
            Swal.fire('OK', '', 'info');
          }
        });
      } else {
        setWeb3Api(
          createWeb3State({
            web3,
            gameContract,
            provider,
            account: newAccount,
            isLoading: false,
            foMoERC721
          })
        );
        Toast.fire({
          icon: 'success',
          title: 'Connected to Metamask.'
        });
      }

      timer = setInterval(async () => {
        const newfoMoERC721 = await loadContractWithAddress(
          'FoMoERC721',
          web3.utils.toChecksumAddress(REACT_APP_FOMOERC721_CONTRACT_ADDRESS as string),

          web3
        );
        const [newAccount] = await web3.eth.getAccounts();
        if (lastAcoount !== newAccount || !foMoERC721) {
          lastAcoount = newAccount;
          setAccount(newAccount);
          Toast.fire({
            icon: 'success',
            title: 'Connected to Metamask.'
          });
          setWeb3Api((api: any) => ({
            ...api,
            account: newAccount,
            foMoERC721: newfoMoERC721
          }));
        }
      }, 1000);
    };

    loadProvider();
    return () => clearInterval(timer);
  }, []);

  const _web3Api = useMemo(() => {
    const { web3, provider, isLoading, account: lastAccount } = web3Api;
    return {
      ...web3Api,
      isWeb3Loaded: web3 != null,
      requireInstall: !isLoading && !web3,
      connect: provider
        ? async () => {
            try {
              await provider.request({ method: 'eth_requestAccounts' });
            } catch (error) {
              Toast.fire({
                icon: 'error',
                title: 'Can not connect to metamask, try to reload your browser please.'
              });
              // window.location.reload();
            }
          }
        : () => {
            Toast.fire({
              icon: 'error',
              title: 'Can not connect to metamask, try to reload your browser please.'
            });
          },
      switchNetwork: provider
        ? async (chainId: string = '31337') => {
            try {
              await provider.request({
                method: 'wallet_switchEthereumChain',
                params: [{ chainId: '0x' + (31337).toString(16) }]
              });
            } catch (error) {
              Toast.fire({
                icon: 'error',
                title: 'Fail to switch network!'
              });
            }
          }
        : () => {
            Toast.fire({
              icon: 'error',
              title: 'Fail to switch network!'
            });
          }
    };
  }, [web3Api, nowAccount]);

  return (
    // @ts-ignore
    <Web3Context.Provider value={_web3Api}>{children}</Web3Context.Provider>
  );
}

export function useWeb3(): Web3State {
  // @ts-ignore
  return useContext(Web3Context);
}

export function useHooks(cb: any) {
  const { hooks } = useWeb3() as unknown as Web3State;
  return cb(hooks);
}
