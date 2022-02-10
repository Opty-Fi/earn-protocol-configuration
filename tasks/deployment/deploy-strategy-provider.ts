import { task, types } from "hardhat/config";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import { isAddress, executeFunc, deployContract } from "../../helpers/helpers";
import TASKS from "../task-names";

task(TASKS.DEPLOYMENT_TASKS.DEPLOY_STRATEGY_PROVIDER.NAME, TASKS.DEPLOYMENT_TASKS.DEPLOY_STRATEGY_PROVIDER.DESCRIPTION)
  .addParam("registry", "the address of registry", "", types.string)
  .addParam("deployedonce", "allow checking whether contracts were deployed previously", true, types.boolean)
  .addParam("contractversion", "the version of strategy provider", 1, types.int)
  .setAction(async ({ deployedonce, registry, contractversion }, hre) => {
    if (registry === "") {
      throw new Error("registry cannot be empty");
    }

    if (!isAddress(registry)) {
      throw new Error("registry address is invalid");
    }

    if (contractversion !== 1 && contractversion !== 2) {
      throw new Error("contractversion is invalid");
    }

    try {
      const [owner] = await hre.ethers.getSigners();
      console.log("Deploying StrategyProvider...");
      const strategyProvider = await deployContract(
        hre,
        contractversion === 1 ? ESSENTIAL_CONTRACTS.STRATEGY_PROVIDER : ESSENTIAL_CONTRACTS.STRATEGY_PROVIDER_V2,
        deployedonce,
        owner,
        [registry],
      );
      console.log("Finished deploying strategyProvider");
      console.log(`Contract strategyProvider : ${strategyProvider.address}`);
      console.log("Registering StrategyProvider...");
      const registryContract = await hre.ethers.getContractAt(
        contractversion === 1 ? ESSENTIAL_CONTRACTS.REGISTRY : ESSENTIAL_CONTRACTS.REGISTRY_V2,
        registry,
      );
      await executeFunc(registryContract, owner, "setStrategyProvider(address)", [strategyProvider.address]);
      console.log("Registered StrategyProvider.");
    } catch (error) {
      console.error(`${TASKS.DEPLOYMENT_TASKS.DEPLOY_STRATEGY_PROVIDER.NAME}: `, error);
      throw error;
    }
  });
