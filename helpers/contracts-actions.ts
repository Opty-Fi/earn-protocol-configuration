import { Contract, Signer } from "ethers";
import { getAddress } from "ethers/lib/utils";
import { expect } from "chai";
import { STRATEGY_DATA } from "./type";
import { executeFunc, generateTokenHash, isAddress } from "./helpers";
import { RISK_PROFILES } from "./constants/contracts-data";

export async function approveLiquidityPoolAndMapAdapter(
  owner: Signer,
  registryContract: Contract,
  adapter: string,
  lqPool: string,
  checkApproval: boolean,
): Promise<void> {
  try {
    if (checkApproval) {
      const { isLiquidityPool } = await registryContract.getLiquidityPool(lqPool);
      if (!isLiquidityPool) {
        await expect(registryContract.connect(owner)["approveLiquidityPool(address)"](lqPool))
          .to.emit(registryContract, "LogLiquidityPool")
          .withArgs(getAddress(lqPool), true, await owner.getAddress());
      }
      await expect(registryContract.connect(owner)["setLiquidityPoolToAdapter(address,address)"](lqPool, adapter))
        .to.emit(registryContract, "LogLiquidityPoolToAdapter")
        .withArgs(getAddress(lqPool), adapter, await owner.getAddress());
    } else {
      await registryContract.connect(owner)["approveLiquidityPoolAndMapToAdapter(address,address)"](lqPool, adapter);
    }
  } catch (error) {
    console.error(`contract-actions#approveLiquidityPoolAndMapAdapter: `, error);
    throw error;
  }
}

export async function approveLiquidityPoolAndMapAdapters(
  owner: Signer,
  registryContract: Contract,
  lqPools: string[],
  lqPoolsMapToAdapter: string[][],
  checkApproval: boolean,
): Promise<void> {
  try {
    if (checkApproval) {
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
      await executeFunc(registryContract, owner, "setLiquidityPoolToAdapter((address,address)[])", [
        lqPoolsMapToAdapter,
      ]);
    } else {
      await executeFunc(registryContract, owner, "approveLiquidityPoolAndMapToAdapter((address,address)[])", [
        lqPoolsMapToAdapter,
      ]);
    }
  } catch (error) {
    console.error(`contracts-actions#approveLiquidityPoolAndMapAdapters: `, error);
    throw error;
  }
}

export async function approveAndMapTokenHashToToken(
  owner: Signer,
  registryContract: Contract,
  tokenAddress: string,
  chainId: string,
  checkApproval: boolean,
): Promise<void> {
  try {
    if (checkApproval) {
      const isApprovedToken = await registryContract.isApprovedToken(tokenAddress);
      if (!isApprovedToken) {
        await expect(executeFunc(registryContract, owner, "approveToken(address)", [tokenAddress]))
          .to.emit(registryContract, "LogToken")
          .withArgs(getAddress(tokenAddress), true, await owner.getAddress());
      }
      if (!(await isSetTokenHash(registryContract, [tokenAddress], chainId))) {
        const tokenHash = generateTokenHash([tokenAddress], chainId);
        await executeFunc(registryContract, owner, "setTokensHashToTokens(bytes32,address[])", [
          tokenHash,
          [tokenAddress],
        ]);
      }
    } else {
      const tokenHash = generateTokenHash([tokenAddress], chainId);
      await executeFunc(registryContract, owner, "approveTokenAndMapToTokensHash(bytes32,address[])", [
        tokenHash,
        [tokenAddress],
      ]);
    }
  } catch (error) {
    console.error(`contract-actions#approveAndMapTokenHashToToken : `, error);
    throw error;
  }
}

export async function approveAndMapTokenHashToTokens(
  owner: Signer,
  registryContract: Contract,
  tokenAddresses: string[],
  setTokenHashForEach: boolean,
  chainId: string,
  checkApproval: boolean,
): Promise<void> {
  try {
    const setTokenHashLists: string[] = [];
    for (const tokenAddress of tokenAddresses) {
      if (setTokenHashForEach) {
        if (!(await isSetTokenHash(registryContract, [tokenAddress], chainId))) {
          setTokenHashLists.push(tokenAddress);
        }
      }
    }
    if (checkApproval) {
      const approveTokenLists: string[] = [];
      for (const tokenAddress of tokenAddresses) {
        const isApprovedToken = await registryContract.isApprovedToken(tokenAddress);
        if (!isApprovedToken) {
          approveTokenLists.push(tokenAddress);
        }
      }
      if (approveTokenLists.length > 0) {
        await executeFunc(registryContract, owner, "approveToken(address[])", [approveTokenLists]);
      }
      if (setTokenHashLists.length > 0) {
        const tokens = setTokenHashLists.map(addr => [generateTokenHash([addr], chainId), [addr]]);
        await executeFunc(registryContract, owner, "setTokensHashToTokens((bytes32,address[])[])", [tokens]);
      } else {
        if (!(await isSetTokenHash(registryContract, tokenAddresses, chainId))) {
          await executeFunc(registryContract, owner, "setTokensHashToTokens((bytes32,address[])[])", [
            [[generateTokenHash(tokenAddresses, chainId), tokenAddresses]],
          ]);
        }
      }
    } else {
      if (setTokenHashLists.length > 0) {
        const tokens = setTokenHashLists.map(addr => [generateTokenHash([addr], chainId), [addr]]);
        await executeFunc(registryContract, owner, "approveTokenAndMapToTokensHash((bytes32,address[])[])", [tokens]);
      } else {
        if (!(await isSetTokenHash(registryContract, tokenAddresses, chainId))) {
          await executeFunc(registryContract, owner, "approveTokenAndMapToTokensHash((bytes32,address[])[])", [
            [[generateTokenHash(tokenAddresses, chainId), tokenAddresses]],
          ]);
        }
      }
    }
  } catch (error) {
    console.error(`contract-actions#approveAndMapTokenHashToTokens: `, error);
    throw error;
  }
}

export async function setBestStrategy(
  strategy: STRATEGY_DATA[],
  tokenAddress: string,
  strategyProvider: Contract,
  riskProfileCode: number,
  isDefault: boolean,
  chainId: string,
): Promise<void> {
  const tokenHash = generateTokenHash([tokenAddress], chainId);

  if (isDefault) {
    await strategyProvider.setBestDefaultStrategy(
      riskProfileCode,
      tokenHash,
      strategy.map(item => [item.contract, item.outputToken, item.isSwap]),
    );
  } else {
    await strategyProvider.setBestStrategy(
      riskProfileCode,
      tokenHash,
      strategy.map(item => [item.contract, item.outputToken, item.isSwap]),
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

export async function isSetTokenHash(
  registryContract: Contract,
  tokenAddresses: string[],
  chainId: string,
): Promise<boolean> {
  const tokensHash = generateTokenHash(tokenAddresses, chainId);
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
  poolRating: number[],
): Promise<void> {
  const profile = await registry.getRiskProfile(riskProfileCode);
  if (!profile.exists) {
    const _addRiskProfileTx = await registry
      .connect(owner)
      ["addRiskProfile(uint256,string,string,(uint8,uint8))"](riskProfileCode, name, symbol, poolRating);
    const ownerAddress = await owner.getAddress();
    const addRiskProfileTx = await _addRiskProfileTx.wait(1);
    const { index } = await registry.getRiskProfile(riskProfileCode);
    expect(addRiskProfileTx.events[0].event).to.equal("LogRiskProfile");
    expect(addRiskProfileTx.events[0].args[0]).to.equal(+index);
    expect(addRiskProfileTx.events[0].args[1]).to.equal(true);
    expect(addRiskProfileTx.events[0].args[2]).to.equal(false);
    expect(addRiskProfileTx.events[0].args[3]).to.equal(ownerAddress);
    expect(addRiskProfileTx.events[1].event).to.equal("LogRPPoolRatings");
    expect(addRiskProfileTx.events[1].args[0]).to.equal(+index);
    expect(addRiskProfileTx.events[1].args[1]).to.equal(poolRating[0]);
    expect(addRiskProfileTx.events[1].args[2]).to.equal(poolRating[1]);
    expect(addRiskProfileTx.events[1].args[3]).to.equal(ownerAddress);
  }
}
