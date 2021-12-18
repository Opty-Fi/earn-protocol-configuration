import { task, types } from "hardhat/config";
import { deployRegistry } from "../../helpers/contracts-deployments";
import { DEPLOY_REGISTRY } from "../task-names";

task(DEPLOY_REGISTRY, "Deploy Registry")
  .addParam("deployedonce", "allow checking whether contracts were deployed previously", true, types.boolean)
  .setAction(async ({ deployedonce }, hre) => {
    try {
      const [owner] = await hre.ethers.getSigners();
      console.log("Deploying Registry...");
      const registry = await deployRegistry(hre, owner, deployedonce);
      console.log("Finished deploying registry");
      console.log(`Contract registry : ${registry.address}`);
    } catch (error) {
      console.error(`${DEPLOY_REGISTRY}: `, error);
      throw error;
    }
  });
