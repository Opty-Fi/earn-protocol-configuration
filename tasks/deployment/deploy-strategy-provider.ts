import { task, types } from "hardhat/config";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import { isAddress, executeFunc, deployContract } from "../../helpers/helpers";
import { DEPLOY_STRATEGY_PROVIDER } from "../task-names";

task(DEPLOY_STRATEGY_PROVIDER, "Deploy Strategy Provider")
  .addParam("registry", "the address of registry", "", types.string)
  .addParam("deployedonce", "allow checking whether contracts were deployed previously", true, types.boolean)
  .setAction(async ({ deployedonce, registry }, hre) => {
    if (registry === "") {
      throw new Error("registry cannot be empty");
    }

    if (!isAddress(registry)) {
      throw new Error("registry address is invalid");
    }

    try {
      const [owner] = await hre.ethers.getSigners();
      console.log("Deploying StrategyProvider...");
      const strategyProvider = await deployContract(hre, ESSENTIAL_CONTRACTS.STRATEGY_PROVIDER, deployedonce, owner, [
        registry,
      ]);
      console.log("Finished deploying strategyProvider");
      console.log(`Contract strategyProvider : ${strategyProvider.address}`);
      console.log("Registering StrategyProvider...");
      const registryContract = await hre.ethers.getContractAt(ESSENTIAL_CONTRACTS.REGISTRY, registry);
      await executeFunc(registryContract, owner, "setStrategyProvider(address)", [strategyProvider.address]);
      console.log("Registered StrategyProvider.");
    } catch (error) {
      console.error(`${DEPLOY_STRATEGY_PROVIDER}: `, error);
      throw error;
    }
  });
