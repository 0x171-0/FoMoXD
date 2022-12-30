const { REACT_APP_STATIC_URL } = process.env;

export const loadContract = async (name: string, web3: any) => {
  let contract = null;

  try {
    const res = await fetch(`${REACT_APP_STATIC_URL}/contracts/${name}.json`);
    const Artifact = await res.json();

    let networkId = 43113; // FUJI Tesnet

    contract = new web3.eth.Contract(Artifact.abi, Artifact.networks[networkId].address);
  } catch (e) {
    console.log(`Contract ${name} not found`);
  }

  return contract;
};

export const loadContractWithAddress = async (name: string, address: string, web3: any) => {
  let contract = null;
  try {
    const res = await fetch(`${REACT_APP_STATIC_URL}/contracts/${name}.json`);
    const Artifact = await res.json();
    contract = new web3.eth.Contract(Artifact.abi, address);
  } catch (e) {
    console.log(`Contract ${name} not found`, e);
  }

  return contract;
};
