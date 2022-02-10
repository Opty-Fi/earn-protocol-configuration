import { task, types } from "hardhat/config";

import { CONTRACTS } from "../helpers/type";
import { deployEssentialContracts } from "../helpers/contracts-deployments";
import TASKS from "./task-names";
import { NETWORKS_ID } from "../helpers/constants/network";

task(TASKS.SETUP.NAME, TASKS.SETUP.DESCRIPTION)
  .addParam("contractversion", "the version of contracts", 1, types.int)
  .addParam("deployedonce", "allow checking whether contracts were deployed previously", false, types.boolean)
  .setAction(async ({ deployedonce, contractversion }, hre) => {
    console.log(`\tDeploying Infrastructure contracts ...`);
    const [owner] = await hre.ethers.getSigners();
    let essentialContracts: CONTRACTS;
    if (contractversion !== 1 && contractversion !== 2) {
      throw new Error("contractversion is invalid");
    }
    try {
      essentialContracts = await deployEssentialContracts(hre, owner, deployedonce, contractversion);
      const essentialContractNames = Object.keys(essentialContracts);
      for (let i = 0; i < essentialContractNames.length; i++) {
        console.log(
          `${essentialContractNames[i].toUpperCase()} address : ${
            essentialContracts[essentialContractNames[i]].address
          }`,
        );
      }
      console.log("********************");
    } catch (error) {
      console.error(`deployEssentialContracts: `, error);
      throw error;
    }
    console.log("********************");
    console.log(`\tApproving Tokens...`);

    await hre.run(TASKS.ACTION_TASKS.APPROVE_TOKENS.NAME, {
      registry: essentialContracts["registry"].address,
      chainid: NETWORKS_ID.MAINNET,
      contractversion: contractversion,
    });

    console.log("********************");
    console.log("Finished setup task");
  });
