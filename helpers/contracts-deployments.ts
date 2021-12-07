import { RISK_PROFILES } from "./constants/contracts-data";
import { VAULT_TOKENS } from "./constants/tokens";
import { ESSENTIAL_CONTRACTS as ESSENTIAL_CONTRACTS_DATA } from "./constants/essential-contracts-name";
import { Contract, Signer } from "ethers";
import { CONTRACTS, CONTRACTS_WITH_HASH } from "./type";
import { addRiskProfiles, getBlockTimestamp } from "./contracts-actions";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, executeFunc } from "./helpers";

export async function deployRegistry(
  hre: HardhatRuntimeEnvironment,
  owner: Signer,
  isDeployedOnce: boolean,
): Promise<Contract> {
  let registry = await deployContract(hre, ESSENTIAL_CONTRACTS_DATA.REGISTRY, isDeployedOnce, owner, []);
  const registryProxy = await deployContract(hre, ESSENTIAL_CONTRACTS_DATA.REGISTRY_PROXY, isDeployedOnce, owner, []);
  await executeFunc(registryProxy, owner, "setPendingImplementation(address)", [registry.address]);
  await executeFunc(registry, owner, "become(address)", [registryProxy.address]);
  registry = await hre.ethers.getContractAt(ESSENTIAL_CONTRACTS_DATA.REGISTRY, registryProxy.address, owner);
  return registry;
}

export async function deployRiskManager(
  hre: HardhatRuntimeEnvironment,
  owner: Signer,
  isDeployedOnce: boolean,
  registry: string,
): Promise<Contract> {
  let riskManager = await deployContract(hre, ESSENTIAL_CONTRACTS_DATA.RISK_MANAGER, isDeployedOnce, owner, [registry]);

  const riskManagerProxy = await deployContract(
    hre,
    ESSENTIAL_CONTRACTS_DATA.RISK_MANAGER_PROXY,
    isDeployedOnce,
    owner,
    [registry],
  );

  await executeFunc(riskManagerProxy, owner, "setPendingImplementation(address)", [riskManager.address]);
  await executeFunc(riskManager, owner, "become(address)", [riskManagerProxy.address]);

  riskManager = await hre.ethers.getContractAt(ESSENTIAL_CONTRACTS_DATA.RISK_MANAGER, riskManagerProxy.address, owner);

  return riskManager;
}

export async function deployEssentialContracts(
  hre: HardhatRuntimeEnvironment,
  owner: Signer,
  isDeployedOnce: boolean,
): Promise<CONTRACTS> {
  console.log("\n Deploying Registry...");
  const registry = await deployRegistry(hre, owner, isDeployedOnce);
  console.log("\n Adding risk profiles...");
  await addRiskProfiles(owner, registry);
  const investStrategyRegistry = await deployContract(
    hre,
    ESSENTIAL_CONTRACTS_DATA.INVEST_STRATEGY_REGISTRY,
    isDeployedOnce,
    owner,
    [registry.address],
  );

  await executeFunc(registry, owner, "setInvestStrategyRegistry(address)", [investStrategyRegistry.address]);
  const strategyProvider = await deployContract(
    hre,
    ESSENTIAL_CONTRACTS_DATA.STRATEGY_PROVIDER,
    isDeployedOnce,
    owner,
    [registry.address],
  );
  await executeFunc(registry, owner, "setStrategyProvider(address)", [strategyProvider.address]);
  const aprOracle = await deployContract(hre, ESSENTIAL_CONTRACTS_DATA.APR_ORACLE, isDeployedOnce, owner, [
    registry.address,
  ]);
  await executeFunc(registry, owner, "setAPROracle(address)", [aprOracle.address]);
  const harvestCodeProvider = await deployContract(
    hre,
    ESSENTIAL_CONTRACTS_DATA.HARVEST_CODE_PROVIDER,
    isDeployedOnce,
    owner,
    [registry.address],
  );
  await executeFunc(registry, owner, "setHarvestCodeProvider(address)", [harvestCodeProvider.address]);
  const riskManager = await deployRiskManager(hre, owner, isDeployedOnce, registry.address);
  await executeFunc(registry, owner, "setRiskManager(address)", [riskManager.address]);
  const strategyManager = await deployContract(hre, ESSENTIAL_CONTRACTS_DATA.STRATEGY_MANAGER, isDeployedOnce, owner, [
    registry.address,
  ]);
  await executeFunc(registry, owner, "setStrategyManager(address)", [strategyManager.address]);

  const opty = await deployContract(hre, ESSENTIAL_CONTRACTS_DATA.OPTY, isDeployedOnce, owner, [
    registry.address,
    100000000000000,
  ]);

  const timestamp = (await getBlockTimestamp(hre)) + 450000;
  const optyDistributor = await deployContract(hre, ESSENTIAL_CONTRACTS_DATA.OPTY_DISTRIBUTOR, isDeployedOnce, owner, [
    registry.address,
    opty.address,
    timestamp,
  ]);

  await executeFunc(registry, owner, "setOPTYDistributor(address)", [optyDistributor.address]);

  const optyStakingRateBalancer = await deployOptyStakingRateBalancer(hre, owner, isDeployedOnce, registry.address);

  await executeFunc(registry, owner, "setOPTYStakingRateBalancer(address)", [optyStakingRateBalancer.address]);

  const optyStakingVaults = await deployAndSetupOptyStakingVaults(
    hre,
    owner,
    isDeployedOnce,
    registry.address,
    opty.address,
    optyStakingRateBalancer,
    optyDistributor,
  );

  await executeFunc(optyStakingRateBalancer, owner, "setStakingVaultOPTYAllocation(uint256)", [10000000000]);

  const essentialContracts: CONTRACTS = {
    registry,
    investStrategyRegistry,
    strategyProvider,
    strategyManager,
    optyDistributor,
    opty,
    riskManager,
    harvestCodeProvider,
    optyStakingRateBalancer,
    optyStakingVault1D: optyStakingVaults["optyStakingVault1D"],
    optyStakingVault30D: optyStakingVaults["optyStakingVault30D"],
    optyStakingVault60D: optyStakingVaults["optyStakingVault60D"],
    optyStakingVault180D: optyStakingVaults["optyStakingVault180D"],
  };

  return essentialContracts;
}
