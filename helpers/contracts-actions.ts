import { Contract, Signer } from "ethers";
import { getAddress } from "ethers/lib/utils";
import { expect } from "chai";
import { STRATEGY_DATA } from "./type";
import {
  executeFunc,
  generateStrategyStep,
  generateStrategyHash,
  generateTokenHashV2,
  generateTokenHash,
  isAddress,
} from "./helpers";
import { RISK_PROFILES } from "./constants/contracts-data";

export async function approveLiquidityPoolAndMapAdapter(
  owner: Signer,
  registryContract: Contract,
  adapter: string,
  lqPool: string,
): Promise<void> {
  const { isLiquidityPool } = await registryContract.getLiquidityPool(lqPool);
  if (!isLiquidityPool) {
    try {
      await expect(registryContract.connect(owner)["approveLiquidityPool(address)"](lqPool))
        .to.emit(registryContract, "LogLiquidityPool")
        .withArgs(getAddress(lqPool), true, await owner.getAddress());
      await expect(registryContract.connect(owner)["setLiquidityPoolToAdapter(address,address)"](lqPool, adapter))
        .to.emit(registryContract, "LogLiquidityPoolToAdapter")
        .withArgs(getAddress(lqPool), adapter, await owner.getAddress());
    } catch (error) {
      console.error(`contract-actions#approveLiquidityPoolAndMapAdapter: `, error);
      throw error;
    }
  }
}

export async function approveLiquidityPoolAndMapAdapters(
  owner: Signer,
  registryContract: Contract,
  lqPools: string[],
  lqPoolsMapToAdapter: string[][],
): Promise<void> {
  try {
    const approveLpList: string[] = [];
    for (let i = 0; i < lqPools.length; i++) {
      const { isLiquidityPool } = await registryContract.getLiquidityPool(lqPools[i]);
      if (!isLiquidityPool) {
        approveLpList.push(lqPools[i]);
      }
    }
    if (approveLpList.length > 0) {
      await executeFunc(registryContract, owner, "approveLiquidityPool(address[])", [approveLpList]);
    }
    await executeFunc(registryContract, owner, "setLiquidityPoolToAdapter((address,address)[])", [lqPoolsMapToAdapter]);
  } catch (error) {
    console.error(`contracts-actions#approveLiquidityPoolAndMapAdapters: `, error);
    throw error;
  }
}

export async function approveLiquidityPoolAndMapAdapterV2(
  owner: Signer,
  registryContractV2: Contract,
  adapter: string,
  lqPool: string,
  checkApproval: boolean,
): Promise<void> {
  try {
    if (checkApproval) {
      const { isLiquidityPool } = await registryContractV2.getLiquidityPool(lqPool);
      if (!isLiquidityPool) {
        await expect(registryContractV2.connect(owner)["approveLiquidityPool(address)"](lqPool))
          .to.emit(registryContractV2, "LogLiquidityPool")
          .withArgs(getAddress(lqPool), true, await owner.getAddress());
      }
      await expect(registryContractV2.connect(owner)["setLiquidityPoolToAdapter(address,address)"](lqPool, adapter))
        .to.emit(registryContractV2, "LogLiquidityPoolToAdapter")
        .withArgs(getAddress(lqPool), adapter, await owner.getAddress());
    } else {
      await registryContractV2.connect(owner)["approveLiquidityPoolAndMapToAdapter(address,address)"](lqPool, adapter);
    }
  } catch (error) {
    console.error(`contract-actions#approveLiquidityPoolAndMapAdapterV2: `, error);
    throw error;
  }
}

export async function approveLiquidityPoolAndMapAdaptersV2(
  owner: Signer,
  registryContractV2: Contract,
  lqPools: string[],
  lqPoolsMapToAdapter: string[][],
  checkApproval: boolean,
): Promise<void> {
  try {
    if (checkApproval) {
      const approveLpList: string[] = [];
      for (let i = 0; i < lqPools.length; i++) {
        const { isLiquidityPool } = await registryContractV2.getLiquidityPool(lqPools[i]);
        if (!isLiquidityPool) {
          approveLpList.push(lqPools[i]);
        }
      }
      if (approveLpList.length > 0) {
        await executeFunc(registryContractV2, owner, "approveLiquidityPool(address[])", [approveLpList]);
      }
      await executeFunc(registryContractV2, owner, "setLiquidityPoolToAdapter((address,address)[])", [
        lqPoolsMapToAdapter,
      ]);
    } else {
      await executeFunc(registryContractV2, owner, "approveLiquidityPoolAndMapToAdapter((address,address)[])", [
        lqPoolsMapToAdapter,
      ]);
    }
  } catch (error) {
    console.error(`contracts-actions#approveLiquidityPoolAndMapAdaptersV2: `, error);
    throw error;
  }
}

export async function approveAndMapTokenHashToToken(
  owner: Signer,
  registryContract: Contract,
  tokenAddress: string,
): Promise<void> {
  try {
    const isApprovedToken = await registryContract.isApprovedToken(tokenAddress);
    if (!isApprovedToken) {
      await expect(executeFunc(registryContract, owner, "approveToken(address)", [tokenAddress]))
        .to.emit(registryContract, "LogToken")
        .withArgs(getAddress(tokenAddress), true, await owner.getAddress());
    }
    if (!(await isSetTokenHash(registryContract, [tokenAddress]))) {
      await executeFunc(registryContract, owner, "setTokensHashToTokens(address[])", [[tokenAddress]]);
    }
  } catch (error) {
    console.error(`contract-actions#approveAndSetTokenHashToToken : `, error);
    throw error;
  }
}

export async function approveAndMapTokenHashToTokens(
  owner: Signer,
  registryContract: Contract,
  tokenAddresses: string[],
  setTokenHashForEach: boolean,
): Promise<void> {
  try {
    const approveTokenLists: string[] = [];
    const setTokenHashLists: string[] = [];
    for (const tokenAddress of tokenAddresses) {
      const isApprovedToken = await registryContract.isApprovedToken(tokenAddress);
      if (!isApprovedToken) {
        approveTokenLists.push(tokenAddress);
      }
      if (setTokenHashForEach) {
        if (!(await isSetTokenHash(registryContract, [tokenAddress]))) {
          setTokenHashLists.push(tokenAddress);
        }
      }
    }
    if (approveTokenLists.length > 0) {
      await executeFunc(registryContract, owner, "approveToken(address[])", [approveTokenLists]);
    }
    if (setTokenHashLists.length > 0) {
      await executeFunc(registryContract, owner, "setTokensHashToTokens(address[][])", [
        setTokenHashLists.map(addr => [addr]),
      ]);
    } else {
      if (!(await isSetTokenHash(registryContract, tokenAddresses))) {
        await executeFunc(registryContract, owner, "setTokensHashToTokens(address[][])", [[tokenAddresses]]);
      }
    }
  } catch (error) {
    console.error(`contract-actions#approveAndSetTokenHashToTokens: `, error);
    throw error;
  }
}

export async function approveAndMapTokenHashToTokenV2(
  owner: Signer,
  registryContractV2: Contract,
  tokenAddress: string,
  chainId: string,
  checkApproval: boolean,
): Promise<void> {
  try {
    if (checkApproval) {
      const isApprovedToken = await registryContractV2.isApprovedToken(tokenAddress);
      if (!isApprovedToken) {
        await expect(executeFunc(registryContractV2, owner, "approveToken(address)", [tokenAddress]))
          .to.emit(registryContractV2, "LogToken")
          .withArgs(getAddress(tokenAddress), true, await owner.getAddress());
      }
      if (!(await isSetTokenHashV2(registryContractV2, [tokenAddress], chainId))) {
        const tokenHash = generateTokenHashV2([tokenAddress], chainId);
        await executeFunc(registryContractV2, owner, "setTokensHashToTokens(bytes32,address[])", [
          tokenHash,
          [tokenAddress],
        ]);
      }
    } else {
      const tokenHash = generateTokenHashV2([tokenAddress], chainId);
      await executeFunc(registryContractV2, owner, "approveTokenAndMapToTokensHash(bytes32,address[])", [
        tokenHash,
        [tokenAddress],
      ]);
    }
  } catch (error) {
    console.error(`contract-actions#approveAndMapTokenHashToToken : `, error);
    throw error;
  }
}

export async function approveAndMapTokenHashToTokensV2(
  owner: Signer,
  registryContractV2: Contract,
  tokenAddresses: string[],
  setTokenHashForEach: boolean,
  chainId: string,
  checkApproval: boolean,
): Promise<void> {
  try {
    const setTokenHashLists: string[] = [];
    for (const tokenAddress of tokenAddresses) {
      if (setTokenHashForEach) {
        if (!(await isSetTokenHashV2(registryContractV2, [tokenAddress], chainId))) {
          setTokenHashLists.push(tokenAddress);
        }
      }
    }
    if (checkApproval) {
      const approveTokenLists: string[] = [];
      for (const tokenAddress of tokenAddresses) {
        const isApprovedToken = await registryContractV2.isApprovedToken(tokenAddress);
        if (!isApprovedToken) {
          approveTokenLists.push(tokenAddress);
        }
      }
      if (approveTokenLists.length > 0) {
        await executeFunc(registryContractV2, owner, "approveToken(address[])", [approveTokenLists]);
      }
      if (setTokenHashLists.length > 0) {
        const tokens = setTokenHashLists.map(addr => [generateTokenHashV2([addr], chainId), [addr]]);
        await executeFunc(registryContractV2, owner, "setTokensHashToTokens((bytes32,address[])[])", [tokens]);
      } else {
        if (!(await isSetTokenHashV2(registryContractV2, tokenAddresses, chainId))) {
          await executeFunc(registryContractV2, owner, "setTokensHashToTokens((bytes32,address[])[])", [
            [[generateTokenHashV2(tokenAddresses, chainId), tokenAddresses]],
          ]);
        }
      }
    } else {
      if (setTokenHashLists.length > 0) {
        const tokens = setTokenHashLists.map(addr => [generateTokenHashV2([addr], chainId), [addr]]);
        await executeFunc(registryContractV2, owner, "approveTokenAndMapToTokensHash((bytes32,address[])[])", [tokens]);
      } else {
        if (!(await isSetTokenHashV2(registryContractV2, tokenAddresses, chainId))) {
          await executeFunc(registryContractV2, owner, "approveTokenAndMapToTokensHash((bytes32,address[])[])", [
            [[generateTokenHashV2(tokenAddresses, chainId), tokenAddresses]],
          ]);
        }
      }
    }
  } catch (error) {
    console.error(`contract-actions#approveAndMapTokenHashToTokens: `, error);
    throw error;
  }
}

export async function setStrategy(
  strategy: STRATEGY_DATA[],
  signer: Signer,
  tokens: string[],
  investStrategyRegistry: Contract,
): Promise<string> {
  const strategySteps: [string, string, boolean][] = generateStrategyStep(strategy);
  const tokensHash = generateTokenHash(tokens);
  const strategyHash = generateStrategyHash(strategy, tokens[0]);
  await expect(
    investStrategyRegistry.connect(signer)["setStrategy(bytes32,(address,address,bool)[])"](tokensHash, strategySteps),
  )
    .to.emit(investStrategyRegistry, "LogSetVaultInvestStrategy")
    .withArgs(tokensHash, strategyHash, await signer.getAddress());
  return strategyHash;
}

export async function setBestStrategy(
  strategy: STRATEGY_DATA[],
  tokenAddress: string,
  strategyProvider: Contract,
  riskProfileCode: number,
  isDefault: boolean,
  chainId: string,
): Promise<void> {
  const tokenHash = generateTokenHashV2([tokenAddress], chainId);

  if (isDefault) {
    await strategyProvider.setBestDefaultStrategy(
      riskProfileCode,
      tokenHash,
      strategy.map(item => [item.contract, item.outputToken, item.isBorrow]),
    );
  } else {
    await strategyProvider.setBestStrategy(
      riskProfileCode,
      tokenHash,
      strategy.map(item => [item.contract, item.outputToken, item.isBorrow]),
    );
  }
}

export async function unpauseVault(
  owner: Signer,
  registryContract: Contract,
  vaultAddr: string,
  unpaused: boolean,
): Promise<void> {
  await expect(executeFunc(registryContract, owner, "unpauseVaultContract(address,bool)", [vaultAddr, unpaused]))
    .to.emit(registryContract, "LogUnpauseVault")
    .withArgs(vaultAddr, unpaused, await owner.getAddress());
}

export async function isSetTokenHashV2(
  registryContractV2: Contract,
  tokenAddresses: string[],
  chainId: string,
): Promise<boolean> {
  const tokensHash = generateTokenHashV2(tokenAddresses, chainId);
  const tokenAddressesInContract = await registryContractV2.getTokensHashToTokenList(tokensHash);
  if (tokenAddressesInContract.length === 0) {
    return false;
  }
  for (let i = 0; i < tokenAddresses.length; i++) {
    if (
      isAddress(tokenAddressesInContract[i]) &&
      getAddress(tokenAddressesInContract[i]) !== getAddress(tokenAddresses[i])
    ) {
      return false;
    }
  }
  return true;
}

export async function isSetTokenHash(registryContract: Contract, tokenAddresses: string[]): Promise<boolean> {
  const tokensHash = generateTokenHash(tokenAddresses);
  const tokenAddressesInContract = await registryContract.getTokensHashToTokenList(tokensHash);
  if (tokenAddressesInContract.length === 0) {
    return false;
  }
  for (let i = 0; i < tokenAddresses.length; i++) {
    if (
      isAddress(tokenAddressesInContract[i]) &&
      getAddress(tokenAddressesInContract[i]) !== getAddress(tokenAddresses[i])
    ) {
      return false;
    }
  }
  return true;
}

export async function addRiskProfiles(owner: Signer, registry: Contract): Promise<void> {
  for (let i = 0; i < RISK_PROFILES.length; i++) {
    await addRiskProfile(
      registry,
      owner,
      RISK_PROFILES[i].code,
      RISK_PROFILES[i].name,
      RISK_PROFILES[i].symbol,
      RISK_PROFILES[i].canBorrow,
      RISK_PROFILES[i].poolRating,
    );
  }
}

export async function addRiskProfile(
  registry: Contract,
  owner: Signer,
  riskProfileCode: number,
  name: string,
  symbol: string,
  canBorrow: boolean,
  poolRating: number[],
): Promise<void> {
  const profile = await registry.getRiskProfile(riskProfileCode);
  if (!profile.exists) {
    const _addRiskProfileTx = await registry
      .connect(owner)
      ["addRiskProfile(uint256,string,string,bool,(uint8,uint8))"](
        riskProfileCode,
        name,
        symbol,
        canBorrow,
        poolRating,
      );
    const ownerAddress = await owner.getAddress();
    const addRiskProfileTx = await _addRiskProfileTx.wait(1);
    const { index } = await registry.getRiskProfile(riskProfileCode);
    expect(addRiskProfileTx.events[0].event).to.equal("LogRiskProfile");
    expect(addRiskProfileTx.events[0].args[0]).to.equal(+index);
    expect(addRiskProfileTx.events[0].args[1]).to.equal(true);
    expect(addRiskProfileTx.events[0].args[2]).to.equal(canBorrow);
    expect(addRiskProfileTx.events[0].args[3]).to.equal(ownerAddress);
    expect(addRiskProfileTx.events[1].event).to.equal("LogRPPoolRatings");
    expect(addRiskProfileTx.events[1].args[0]).to.equal(+index);
    expect(addRiskProfileTx.events[1].args[1]).to.equal(poolRating[0]);
    expect(addRiskProfileTx.events[1].args[2]).to.equal(poolRating[1]);
    expect(addRiskProfileTx.events[1].args[3]).to.equal(ownerAddress);
  }
}
