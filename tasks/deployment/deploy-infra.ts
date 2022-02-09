import { task, types } from "hardhat/config";
import { CONTRACTS } from "../../helpers/type";
import { deployEssentialContracts } from "../../helpers/contracts-deployments";
import TASKS from "../task-names";

task(TASKS.DEPLOYMENT_TASKS.DEPLOY_INFRA.NAME, TASKS.DEPLOYMENT_TASKS.DEPLOY_INFRA.DESCRIPTION)
  .addParam("deployedonce", "allow checking whether contracts were deployed previously", true, types.boolean)
  .addParam("contractversion", "the version of contracts", 1, types.int)
  .setAction(async ({ deployedonce, contractversion }, hre) => {
    if (contractversion !== 1 || contractversion !== 2) {
      throw new Error("contractversion is invalid");
    }
    try {
      console.log(`\tDeploying Infrastructure contracts ...`);
      const [owner] = await hre.ethers.getSigners();
      const essentialContracts: CONTRACTS = await deployEssentialContracts(hre, owner, deployedonce, contractversion);
      const essentialContractNames = Object.keys(essentialContracts);
      for (let i = 0; i < essentialContractNames.length; i++) {
        console.log(
          `${essentialContractNames[i].toUpperCase()} address : ${
            essentialContracts[essentialContractNames[i]].address
          }`,
        );
      }
      console.log("Finished deploying infrastructure contracts");
    } catch (error) {
      console.error(`${TASKS.DEPLOYMENT_TASKS.DEPLOY_INFRA.NAME}: `, error);
      throw error;
    }
  });
