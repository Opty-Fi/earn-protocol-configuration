import { task, types } from "hardhat/config";
import { deployRiskManager } from "../../helpers/contracts-deployments";
import { isAddress, executeFunc } from "../../helpers/helpers";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import TASKS from "../task-names";

task(TASKS.DEPLOYMENT_TASKS.DEPLOY_RISK_MANAGER.NAME, TASKS.DEPLOYMENT_TASKS.DEPLOY_RISK_MANAGER.DESCRIPTION)
  .addParam("registry", "the address of registry", "", types.string)
  .addParam("deployedonce", "allow checking whether contracts were deployed previously", true, types.boolean)
  .addParam("contractversion", "the version of risk manager", 1, types.int)
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
      console.log("Deploying RiskManager...");
      const riskManagerContract = await deployRiskManager(hre, owner, deployedonce, registry, contractversion);
      console.log("Finished deploying RiskManager");
      console.log(`Contract RiskManager : ${riskManagerContract.address}`);
      console.log("Registering RiskManager...");
      const registryContract = await hre.ethers.getContractAt(
        contractversion === 1 ? ESSENTIAL_CONTRACTS.REGISTRY : ESSENTIAL_CONTRACTS.REGISTRY_V2,
        registry,
      );
      await executeFunc(registryContract, owner, "setRiskManager(address)", [riskManagerContract.address]);
      console.log("Registered RiskManager.");
    } catch (error) {
      console.error(`${TASKS.DEPLOYMENT_TASKS.DEPLOY_RISK_MANAGER.NAME}: `, error);
      throw error;
    }
  });
