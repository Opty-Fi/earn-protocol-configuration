import { task, types } from "hardhat/config";
import { isAddress } from "../../helpers/helpers";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import { VAULT_TOKENS } from "../../helpers/constants/tokens";
import { approveAndMapTokenHashToTokensV2 } from "../../helpers/contracts-actions";
import TASKS from "../task-names";
import { NETWORKS_ID } from "../../helpers/constants/network";

task(TASKS.ACTION_TASKS.APPROVE_TOKENS.NAME, TASKS.ACTION_TASKS.APPROVE_TOKENS.DESCRIPTION)
  .addParam("registry", "the address of registry", "", types.string)
  .addParam("chainid", "the hash of chainid", "", types.string)
  .addParam("checkapproval", "check whether token is approved", false, types.boolean)
  .setAction(async ({ registry, chainid, checkapproval }, hre) => {
    const [owner] = await hre.ethers.getSigners();

    if (registry === "") {
      throw new Error("registry cannot be empty");
    }

    if (!isAddress(registry)) {
      throw new Error("registry address is invalid");
    }

    if (!Object.values(NETWORKS_ID).includes(chainid)) {
      throw new Error("chainid is invalid");
    }

    try {
      const registryContract = await hre.ethers.getContractAt(ESSENTIAL_CONTRACTS.REGISTRY, registry);
      const tokensAddresses = Object.values(VAULT_TOKENS).map(token => token.address);
      console.log(`Start approving tokens....`, tokensAddresses);
      await approveAndMapTokenHashToTokensV2(owner, registryContract, tokensAddresses, true, chainid, checkapproval);
      console.log(`Finished approving tokens`);
    } catch (error) {
      console.error(`${TASKS.ACTION_TASKS.APPROVE_TOKENS.NAME} : `, error);
      throw error;
    }
  });
