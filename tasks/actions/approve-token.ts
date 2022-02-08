import { task, types } from "hardhat/config";
import { isAddress } from "../../helpers/helpers";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import { TypedTokens } from "../../helpers/data";
import { approveAndSetTokenHashToToken } from "../../helpers/contracts-actions";
import { getAddress } from "ethers/lib/utils";
import { APPROVE_TOKEN } from "../task-names";
import { NETWORKS_ID } from "../../helpers/constants/network";

task(APPROVE_TOKEN, "Approve Token")
  .addParam("token", "the address of token", "", types.string)
  .addParam("registry", "the address of registry", "", types.string)
  .addParam("networkHash", "the hash of network", "", types.string)
  .setAction(async ({ token, registry, networkHash }, hre) => {
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

    if (!Object.values(NETWORKS_ID).includes(networkHash)) {
      throw new Error("network is invalid");
    }

    if (getAddress(token) !== getAddress(TypedTokens.ETH)) {
      const registryContract = await hre.ethers.getContractAt(ESSENTIAL_CONTRACTS.REGISTRY, registry);
      try {
        await approveAndSetTokenHashToToken(owner, registryContract, token, networkHash);
        console.log(`Finished approving token: ${token}`);
      } catch (error) {
        console.error(`${APPROVE_TOKEN}:`, error);
        throw error;
      }
    }
  });
