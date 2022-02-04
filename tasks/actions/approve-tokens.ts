import { task, types } from "hardhat/config";
import { isAddress } from "../../helpers/helpers";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import { VAULT_TOKENS } from "../../helpers/constants/tokens";
import { approveAndSetTokenHashToTokens } from "../../helpers/contracts-actions";
import { APPROVE_TOKENS } from "../task-names";
import { NETWORKS_ID } from "../../helpers/constants/network";

task(APPROVE_TOKENS, "Approve Tokens")
  .addParam("registry", "the address of registry", "", types.string)
  .addParam("networkHash", "the hash of network", "", types.string)
  .setAction(async ({ registry, networkHash }, hre) => {
    const [owner] = await hre.ethers.getSigners();

    if (registry === "") {
      throw new Error("registry cannot be empty");
    }

    if (!isAddress(registry)) {
      throw new Error("registry address is invalid");
    }

    if (!Object.values(NETWORKS_ID).includes(networkHash)) {
      throw new Error("network is invalid");
    }

    try {
      const registryContract = await hre.ethers.getContractAt(ESSENTIAL_CONTRACTS.REGISTRY, registry);
      const tokensAddresses = Object.values(VAULT_TOKENS).map(token => token.address);
      console.log(`Start approving tokens....`, tokensAddresses);
      await approveAndSetTokenHashToTokens(owner, registryContract, tokensAddresses, true, networkHash);
      console.log(`Finished approving tokens`);
    } catch (error) {
      console.error(`${APPROVE_TOKENS} : `, error);
      throw error;
    }
  });
