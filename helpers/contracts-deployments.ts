import { ESSENTIAL_CONTRACTS as ESSENTIAL_CONTRACTS_DATA } from "./constants/essential-contracts-name";
import { Contract, Signer } from "ethers";
import { CONTRACTS, VERSION_TYPE } from "./type";
import { addRiskProfiles } from "./contracts-actions";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployContract, executeFunc } from "./helpers";

export async function deployRegistry(
  hre: HardhatRuntimeEnvironment,
  owner: Signer,
  isDeployedOnce: boolean,
  version: VERSION_TYPE,
): Promise<Contract> {
  const registryContractName = version === 1 ? ESSENTIAL_CONTRACTS_DATA.REGISTRY : ESSENTIAL_CONTRACTS_DATA.REGISTRY_V2;

  let registry = await deployContract(hre, registryContractName, isDeployedOnce, owner, []);
  const registryProxy = await deployContract(hre, ESSENTIAL_CONTRACTS_DATA.REGISTRY_PROXY, isDeployedOnce, owner, []);
  await executeFunc(registryProxy, owner, "setPendingImplementation(address)", [registry.address]);
  await executeFunc(registry, owner, "become(address)", [registryProxy.address]);
  registry = await hre.ethers.getContractAt(registryContractName, registryProxy.address, owner);
  return registry;
}

export async function deployRiskManager(
  hre: HardhatRuntimeEnvironment,
  owner: Signer,
  isDeployedOnce: boolean,
  registry: string,
  version: VERSION_TYPE,
): Promise<Contract> {
  const riskManagerContractName =
    version === 1 ? ESSENTIAL_CONTRACTS_DATA.RISK_MANAGER : ESSENTIAL_CONTRACTS_DATA.RISK_MANAGER_V2;

  let riskManager = await deployContract(hre, riskManagerContractName, isDeployedOnce, owner, [registry]);

  const riskManagerProxy = await deployContract(
    hre,
    ESSENTIAL_CONTRACTS_DATA.RISK_MANAGER_PROXY,
    isDeployedOnce,
    owner,
    [registry],
  );

  await executeFunc(riskManagerProxy, owner, "setPendingImplementation(address)", [riskManager.address]);
  await executeFunc(riskManager, owner, "become(address)", [riskManagerProxy.address]);

  riskManager = await hre.ethers.getContractAt(riskManagerContractName, riskManagerProxy.address, owner);

  return riskManager;
}

export async function deployEssentialContracts(
  hre: HardhatRuntimeEnvironment,
  owner: Signer,
  isDeployedOnce: boolean,
  version: VERSION_TYPE,
): Promise<CONTRACTS> {
  console.log("\n Deploying Registry...");
  const registry = await deployRegistry(hre, owner, isDeployedOnce, version);
  console.log("\n Adding risk profiles...");
  await addRiskProfiles(owner, registry);

  const strategyProvider = await deployContract(
    hre,
    ESSENTIAL_CONTRACTS_DATA.STRATEGY_PROVIDER,
    isDeployedOnce,
    owner,
    [registry.address],
  );
  await executeFunc(registry, owner, "setStrategyProvider(address)", [strategyProvider.address]);

  const riskManager = await deployRiskManager(hre, owner, isDeployedOnce, registry.address, version);
  await executeFunc(registry, owner, "setRiskManager(address)", [riskManager.address]);

  const essentialContracts: CONTRACTS = {
    registry,
    strategyProvider,
    riskManager,
  };

  if (version === 1) {
    const investStrategyRegistry = await deployContract(
      hre,
      ESSENTIAL_CONTRACTS_DATA.INVEST_STRATEGY_REGISTRY,
      isDeployedOnce,
      owner,
      [registry.address],
    );

    await executeFunc(registry, owner, "setInvestStrategyRegistry(address)", [investStrategyRegistry.address]);

    const aprOracle = await deployContract(hre, ESSENTIAL_CONTRACTS_DATA.APR_ORACLE, isDeployedOnce, owner, [
      registry.address,
    ]);
    await executeFunc(registry, owner, "setAPROracle(address)", [aprOracle.address]);
  }
  return essentialContracts;
}
