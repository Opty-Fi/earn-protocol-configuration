import { task, types } from "hardhat/config";
import { CONTRACTS } from "../../helpers/type";
import { deployEssentialContracts } from "../../helpers/contracts-deployments";
import { DEPLOY_INFRA } from "../task-names";

task(DEPLOY_INFRA, "Deploy infrastructure contracts")
  .addParam("deployedonce", "allow checking whether contracts were deployed previously", true, types.boolean)
  .setAction(async ({ deployedonce }, hre) => {
    try {
      console.log(`\tDeploying Infrastructure contracts ...`);
      const [owner] = await hre.ethers.getSigners();
      const essentialContracts: CONTRACTS = await deployEssentialContracts(hre, owner, deployedonce);
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
      console.error(`${DEPLOY_INFRA}: `, error);
      throw error;
    }
  });
