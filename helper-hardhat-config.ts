import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, "./.env") });
const GWEI = 1000 * 1000 * 1000;

export enum eEthereumNetwork {
  buidlerevm = "buidlerevm",
  kovan = "kovan",
  ropsten = "ropsten",
  main = "main",
  coverage = "coverage",
  hardhat = "hardhat",
  staging = "staging",
  tenderlyMain = "tenderlyMain",
}

export type iEthereumParamsPerNetwork<T> = {
  [key in eEthereumNetwork]: T;
};

export const NETWORKS_RPC_URL: iEthereumParamsPerNetwork<string> = {
  [eEthereumNetwork.kovan]: process.env.KOVAN_NODE_URL ? process.env.KOVAN_NODE_URL : "",
  [eEthereumNetwork.ropsten]: "",
  [eEthereumNetwork.main]: "",
  [eEthereumNetwork.staging]: process.env.STAGING_NETWORK_URL ? process.env.STAGING_NETWORK_URL : "",
  [eEthereumNetwork.coverage]: "http://localhost:8555",
  [eEthereumNetwork.hardhat]: "http://localhost:8545",
  [eEthereumNetwork.tenderlyMain]: "",
  [eEthereumNetwork.buidlerevm]: "",
};

export const NETWORKS_DEFAULT_GAS: iEthereumParamsPerNetwork<number> = {
  [eEthereumNetwork.kovan]: 65 * GWEI,
  [eEthereumNetwork.ropsten]: 65 * GWEI,
  [eEthereumNetwork.main]: 65 * GWEI,
  [eEthereumNetwork.coverage]: 65 * GWEI,
  [eEthereumNetwork.hardhat]: 65 * GWEI,
  [eEthereumNetwork.staging]: 65 * GWEI,
  [eEthereumNetwork.buidlerevm]: 65 * GWEI,
  [eEthereumNetwork.tenderlyMain]: 0.01 * GWEI,
};

export const NETWORKS_CHAIN_ID_HEX: iEthereumParamsPerNetwork<string> = {
  [eEthereumNetwork.kovan]: "0x2a",
  [eEthereumNetwork.ropsten]: "0x3",
  [eEthereumNetwork.main]: "0x1",
  [eEthereumNetwork.coverage]: "0x7a69",
  [eEthereumNetwork.hardhat]: "0x7a69",
  [eEthereumNetwork.staging]: "0x1",
  [eEthereumNetwork.buidlerevm]: "0x7a69",
  [eEthereumNetwork.tenderlyMain]: "0x1",
};

export const NETWORKS_CHAIN_ID_TO_HEX: { [key: string]: string } = {
  "42": "0x2a",
  "3": "0x3",
  "1": "0x1",
  "31337": "0x7a69",
  "137": "0x89",
  "43114": "0xa86a",
  "1337": "0x539",
  "80001": "0x13881",
};

export const CURRENT_BLOCK_NUMBER = 13837329;
