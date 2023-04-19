import { useState, useEffect, createContext } from "react";
import { useRouter } from "next/router";
import ethers from "ethers";
import { client } from "../constants/sanityClient";
// import config from "../constants/config";

export const TransactionContext = createContext();

let eth;

if (typeof window !== "undefined") {
  eth = window.ethereum;
}

const countPathTokens = (path) => (path.length - 1) / 2 + 1;

const pathToTypes = (path) => {
  return ["address"].concat(
    new Array(countPathTokens(path) - 1).fill(["uint24", "address"]).flat()
  );
};

/**
 * @dev Get smart contract
 */
const getEthereumContract = () => {
  const provider = new ethers.providers.Web3Provider(ethereum);
  const signer = provider.getSigner();
  // contracts
  ManagerContract = new ethers.Contract(
    config.managerAddress,
    config.ABIs.Manager,
    new ethers.providers.Web3Provider(window.ethereum).getSigner()
  );
  QuoterContract = new ethers.Contract(
    config.quoterAddress,
    config.ABIs.Quoter,
    new ethers.providers.Web3Provider(window.ethereum).getSigner()
  );
  TokenInContract = new ethers.Contract(
    config.wethAddress,
    config.ABIs.ERC20,
    new ethers.providers.Web3Provider(window.ethereum).getSigner()
  );
  return ManagerContract, QuoterContract, TokenInContract;
};

export const TransactionProvider = ({ children }) => {
  const [currentAccount, setCurrentAccount] = useState();
  const [isLoading, setIsLoading] = useState(false);
  const [formData, setFormData] = useState({ addressTo: "", amount: "" });
  const router = useRouter();

  /**
   * @dev Trigger loading modal
   */
  useEffect(() => {
    if (isLoading) {
      router.push(`/?loading=${currentAccount}`);
    } else {
      router.push(`/`);
    }
  }, [isLoading]);

  /**
   * @dev Save user's address to Sanity DataBase
   */
  useEffect(() => {
    if (!currentAccount) return;
    (async () => {
      const userDoc = {
        _type: "users",
        _id: currentAccount,
        userName: "Unnamed",
        address: currentAccount,
      };

      await client.createIfNotExists(userDoc);
    })();
  }, [currentAccount]);

  const handleChange = (e, name) => {
    setFormData((prevState) => ({ ...prevState, [name]: e.target.value }));
  };

  /**
   * @dev Check if MetaMask is installed and an account is connected
   * @param {*} metamask metamask object in browser (need to install metamask plugin)
   */
  const checkIfWalletIsConnected = async (metamask = eth) => {
    try {
      if (!metamask) return alert("Please install metamask ");

      const accounts = await metamask.request({ method: "eth_accounts" });

      if (accounts.length) {
        setCurrentAccount(accounts[0]);
      }
    } catch (error) {
      console.error(error);
      throw new Error("No ethereum object.");
    }
  };

  useEffect(() => {
    checkIfWalletIsConnected();
  }, []);

  /**
   * @dev save transaction to Sanity DataBase
   * @param {string} txHash transaction hash
   * @param {number} amount amount of transaction
   * @param {string} fromAddress send account address
   * @param {string} toAddress received account address
   * @returns null
   */
  const saveTransaction = async (
    txHash,
    amount,
    fromAddress = currentAccount,
    toAddress
  ) => {
    const txDoc = {
      _type: "transactions",
      _id: txHash,
      fromAddress: fromAddress,
      toAddress: toAddress,
      timestamp: new Date(Date.now()).toISOString(),
      txHash: txHash,
      amount: parseFloat(amount),
    };

    await client.createIfNotExists(txDoc);

    await client
      .patch(currentAccount)
      .setIfMissing({ transactions: [] })
      .insert("after", "transactions[-1]", [
        { _key: txHash, _ref: txHash, _type: "reference" },
      ])
      .commit();

    return;
  };

  /**
   * @dev send transaction to blockchain
   */
  const sendTransaction = async (
    metamask = eth,
    connectedAccount = currentAccount
  ) => {
    try {
      if (!metamask) return alert("Please install metamask ");
      const { addressTo, amount } = formData;
      const { ManagerContract } = getEthereumContract();

      const parseAmount = ethers.utils.parseEther(amount);

      await metamask.request({
        method: "eth_sendTransaction",
        params: [
          {
            from: connectedAccount,
            to: addressTo,
            gas: 0x7ef40, // 520000 Gwei
            value: parseAmount._hex,
          },
        ],
      });

      const swapTransaction = await ManagerContract.swap({
        path: "",
        recipient: "0x...",
        amountIn: 100,
        minAmountOut: 1,
      });

      setIsLoading(true);

      await swapTransaction.wait();

      /// DB
      await saveTransaction(
        swapTransaction.hash,
        amount,
        connectedAccount,
        addressTo
      );

      setIsLoading(false);
    } catch (error) {
      console.error(error);
    }
  };

  /**
   * @dev Connect user's metamask wallet
   * @param {*} metamask metamask object in browser (need to install metamask plugin)
   */
  const connectWallet = async (metamask = eth) => {
    try {
      if (!metamask) return alert("Please install metamask ");

      const accounts = await metamask.request({
        method: "eth_requestAccounts",
      });

      setCurrentAccount(accounts[0]);
    } catch (error) {
      console.error(error);
      throw new Error("No ethereum object.");
    }
  };

  return (
    <TransactionContext.Provider
      value={{
        connectWallet,
        currentAccount,
        formData,
        setFormData,
        handleChange,
        sendTransaction,
        isLoading,
      }}
    >
      {children}
    </TransactionContext.Provider>
  );
};
