import { Contract, Signer } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { getAddress } from "ethers/lib/utils";
import { expect } from "chai";
import { STRATEGY_DATA } from "./type";
import { executeFunc, generateStrategyHash, generateStrategyStep, generateTokenHash, isAddress } from "./helpers";
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

export async function approveAndSetTokenHashToToken(
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

export async function approveAndSetTokenHashToTokens(
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
  signer: Signer,
  tokenAddress: string,
  investStrategyRegistry: Contract,
  strategyProvider: Contract,
  riskProfileCode: number,
  isDefault: boolean,
): Promise<string> {
  const strategyHash = generateStrategyHash(strategy, tokenAddress);

  const tokenHash = generateTokenHash([tokenAddress]);

  const strategyDetail = await investStrategyRegistry.getStrategy(strategyHash);

  if (strategyDetail[1].length === 0) {
    await setStrategy(strategy, signer, [tokenAddress], investStrategyRegistry);
  }

  if (isDefault) {
    await strategyProvider.setBestDefaultStrategy(riskProfileCode, tokenHash, strategyHash);
  } else {
    await strategyProvider.setBestStrategy(riskProfileCode, tokenHash, strategyHash);
  }
  return strategyHash;
}

export async function getBlockTimestamp(hre: HardhatRuntimeEnvironment): Promise<number> {
  const blockNumber = await hre.ethers.provider.getBlockNumber();
  const block = await hre.ethers.provider.getBlock(blockNumber);
  const timestamp = block.timestamp;
  return timestamp;
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
