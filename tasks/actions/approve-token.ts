import { task, types } from "hardhat/config";
import { isAddress } from "../../helpers/helpers";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import { TypedTokens } from "../../helpers/data";
import { approveAndMapTokenHashToTokenV2 } from "../../helpers/contracts-actions";
import { getAddress } from "ethers/lib/utils";
import TASKS from "../task-names";
import { NETWORKS_ID } from "../../helpers/constants/network";

task(TASKS.ACTION_TASKS.APPROVE_TOKEN.NAME, TASKS.ACTION_TASKS.APPROVE_TOKEN.DESCRIPTION)
  .addParam("token", "the address of token", "", types.string)
  .addParam("registry", "the address of registry", "", types.string)
  .addParam("chainid", "the hash of chainId", "", types.string)
  .addParam("checkapproval", "check whether token is approved", false, types.boolean)
  .setAction(async ({ token, registry, chainid, checkapproval }, hre) => {
    const [owner] = await hre.ethers.getSigners();

    if (registry === "") {
      throw new Error("registry cannot be empty");
    }

    if (!isAddress(registry)) {
      throw new Error("registry address is invalid");
    }

    if (token === "") {
      throw new Error("token cannot be empty");
    }

    if (!isAddress(token)) {
      throw new Error("token address is invalid");
    }

    if (!Object.values(NETWORKS_ID).includes(chainid)) {
      throw new Error("network is invalid");
    }

    if (getAddress(token) !== getAddress(TypedTokens.ETH)) {
      const registryContract = await hre.ethers.getContractAt(ESSENTIAL_CONTRACTS.REGISTRY, registry);
      try {
        await approveAndMapTokenHashToTokenV2(owner, registryContract, token, chainid, checkapproval);
        console.log(`Finished approving token: ${token}`);
      } catch (error) {
        console.error(`${TASKS.ACTION_TASKS.APPROVE_TOKEN.NAME}:`, error);
        throw error;
      }
    }
  });
