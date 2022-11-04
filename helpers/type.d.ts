import { Contract } from "ethers";
import { MockContract } from "@defi-wonderland/smock";

export type ESSENTIAL_CONTRACTS = {
  registry: Contract;
  investStrategyRegistry: Contract;
  strategyProvider: Contract;
  harvestCodeProvider: Contract;
  riskManager: Contract;
  strategyManager: Contract;
  opty: Contract;
  optyDistributor: Contract;
  priceOracle: Contract;
};

export type CONTRACTS = {
  [name: string]: Contract;
};

export type MOCK_CONTRACTS = {
  [name: string]: MockContract<Contract>;
};

export type CONTRACTS_WITH_HASH = {
  [name: string]: { contract: Contract; hash: string };
};

export type DATA_OBJECT = {
  [name: string]: string;
};

export type RISK_PROFILE_DATA = {
  code: number;
  name: string;
  symbol: string;
  poolRating: number[];
}[];

export type STRATEGY = {
  strategyName: string;
  token: string;
  strategy: STRATEGY_DATA[];
};

export type STRATEGY_DATA = {
  contract: string;
  outputTokenSymbol?: string;
  outputToken: string;
  isBorrow: boolean;
};

export type DEFI_POOLS_DATA = {
  [key: string]: {
    [name: string]: {
      pool: string;
      lpToken: string;
      tokens: string[];
      stakingVault?: string;
      pid?: string;
      deprecated?: boolean;
    };
  };
};

export type TESTING_DEFAULT_DATA = {
  setFunction: string;
  input: any[];
  getFunction: {
    name: string;
    input: any[];
    output: any;
  }[];
};

export type TOKENS_DATA = {
  [name: string]: {
    address: string;
    pair: boolean;
  };
};

export type NETWORKS_TYPE = "ethereum" | "polygon";

export type VERSION_TYPE = 1 | 2;

export type CHAINID_NETWORKS = {
  [chainID: string]: {
    name: string;
    network: NETWORKS_TYPE;
  };
};
