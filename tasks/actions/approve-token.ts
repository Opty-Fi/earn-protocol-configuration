import { task, types } from "hardhat/config";
import { isAddress } from "../../helpers/helpers";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import { TypedTokens } from "../../helpers/data";
import { approveAndMapTokenHashToTokenV2, approveAndMapTokenHashToToken } from "../../helpers/contracts-actions";
import { getAddress } from "ethers/lib/utils";
import TASKS from "../task-names";
import { NETWORKS_ID } from "../../helpers/constants/network";

task(TASKS.ACTION_TASKS.APPROVE_TOKEN.NAME, TASKS.ACTION_TASKS.APPROVE_TOKEN.DESCRIPTION)
  .addParam("token", "the address of token", "", types.string)
  .addParam("registry", "the address of registry", "", types.string)
  .addParam("chainid", "the hash of chainId", "", types.string)
  .addParam("checkapproval", "check whether token is approved", false, types.boolean)
  .addParam("contractversion", "the version of registry", 1, types.int)
  .setAction(async ({ token, registry, chainid, checkapproval, contractversion }, hre) => {
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

    if (contractversion !== 1 && contractversion !== 2) {
      throw new Error("contractversion is invalid");
    }

    if (getAddress(token) !== getAddress(TypedTokens.ETH)) {
      const registryContract = await hre.ethers.getContractAt(
        contractversion === 1 ? ESSENTIAL_CONTRACTS.REGISTRY : ESSENTIAL_CONTRACTS.REGISTRY_V2,
        registry,
      );
      try {
        contractversion === 1
          ? await approveAndMapTokenHashToToken(owner, registryContract, token)
          : await approveAndMapTokenHashToTokenV2(owner, registryContract, token, chainid, checkapproval);
        console.log(`Finished approving token: ${token}`);
      } catch (error) {
        console.error(`${TASKS.ACTION_TASKS.APPROVE_TOKEN.NAME}:`, error);
        throw error;
      }
    }
  });
