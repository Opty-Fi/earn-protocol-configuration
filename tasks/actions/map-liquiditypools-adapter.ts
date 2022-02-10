import { task, types } from "hardhat/config";
import { isAddress } from "../../helpers/helpers";

import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import {
  approveLiquidityPoolAndMapAdapters,
  approveLiquidityPoolAndMapAdaptersV2,
} from "../../helpers/contracts-actions";
import { TypedDefiPools } from "../../helpers/data/index";
import { removeDuplicateFromStringArray } from "../../helpers/utils";
import TASKS from "../task-names";

task(
  TASKS.ACTION_TASKS.MAP_LIQUIDITYPOOLS_TO_ADAPTER.NAME,
  TASKS.ACTION_TASKS.MAP_LIQUIDITYPOOLS_TO_ADAPTER.DESCRIPTION,
)
  .addParam("adapter", "the address of defi adapter", "", types.string)
  .addParam("adaptername", "the name of defi adapter", "", types.string)
  .addParam("registry", "the address of registry", "", types.string)
  .addParam("checkapproval", "check whether token is approved", false, types.boolean)
  .addParam("contractversion", "the version of registry", 1, types.int)
  .setAction(async ({ adapter, registry, adaptername, checkapproval, contractversion }, hre) => {
    const [owner] = await hre.ethers.getSigners();

    if (registry === "") {
      throw new Error("registry cannot be empty");
    }

    if (!isAddress(registry)) {
      throw new Error("registry address is invalid");
    }

    if (adapter === "") {
      throw new Error("adapter cannot be empty");
    }

    if (!isAddress(adapter)) {
      throw new Error("adapter address is invalid");
    }

    if (adaptername === "") {
      throw new Error("adaptername cannot be empty");
    }

    if (!TypedDefiPools[adaptername]) {
      throw new Error("wrong adapter name");
    }

    if (contractversion !== 1 && contractversion !== 2) {
      throw new Error("contractversion is invalid");
    }

    try {
      const registryContract = await hre.ethers.getContractAt(
        contractversion === 1 ? ESSENTIAL_CONTRACTS.REGISTRY : ESSENTIAL_CONTRACTS.REGISTRY_V2,
        registry,
      );
      const liquidityPools = removeDuplicateFromStringArray(
        Object.keys(TypedDefiPools[adaptername]).map(name => TypedDefiPools[adaptername][name].pool),
      );
      const liquidityPoolsToAdapter = liquidityPools.map(lp => [lp, adapter as string]);
      contractversion === 1
        ? await approveLiquidityPoolAndMapAdapters(owner, registryContract, liquidityPools, liquidityPoolsToAdapter)
        : await approveLiquidityPoolAndMapAdaptersV2(
            owner,
            registryContract,
            liquidityPools,
            liquidityPoolsToAdapter,
            checkapproval,
          );
      console.log(`Finished mapping liquidityPools to adapter : ${adaptername}`);
      console.log("------------------");
    } catch (error) {
      console.error(`${TASKS.ACTION_TASKS.MAP_LIQUIDITYPOOLS_TO_ADAPTER.NAME}: `, error);
      throw error;
    }
  });
