import { task, types } from "hardhat/config";
import { isAddress } from "../../helpers/helpers";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import {
  approveLiquidityPoolAndMapAdapterV2,
  approveLiquidityPoolAndMapAdapter,
} from "../../helpers/contracts-actions";
import TASKS from "../task-names";

task(TASKS.ACTION_TASKS.MAP_LIQUIDITYPOOL_TO_ADAPTER.NAME, TASKS.ACTION_TASKS.MAP_LIQUIDITYPOOL_TO_ADAPTER.DESCRIPTION)
  .addParam("adapter", "the address of defi adapter", "", types.string)
  .addParam("registry", "the address of registry", "", types.string)
  .addParam("liquiditypool", "the address of liquidity", "", types.string)
  .addParam("checkapproval", "check whether token is approved", false, types.boolean)
  .addParam("contractversion", "the version of registry", 1, types.int)
  .setAction(async ({ adapter, registry, liquiditypool, checkapproval, contractversion }, hre) => {
    const [owner] = await hre.ethers.getSigners();

    if (registry === "") {
      throw new Error("registry cannot be empty");
    }

    if (!isAddress(registry)) {
      throw new Error("registry address is invalid");
    }

    if (liquiditypool === "") {
      throw new Error("liquidity pool cannot be empty");
    }

    if (!isAddress(liquiditypool)) {
      throw new Error("liquidity pool address is invalid");
    }

    if (adapter === "") {
      throw new Error("adapter cannot be empty");
    }

    if (!isAddress(adapter)) {
      throw new Error("adapter address is invalid");
    }

    if (contractversion !== 1 || contractversion !== 2) {
      throw new Error("contractversion is invalid");
    }

    try {
      const registryContract = await hre.ethers.getContractAt(
        contractversion === 1 ? ESSENTIAL_CONTRACTS.REGISTRY : ESSENTIAL_CONTRACTS.REGISTRY_V2,
        registry,
      );
      console.log(`Start mapping liquidity pool to adapter.....`);
      console.log(`Adapter: ${adapter}`);
      console.log(`Liquidity pool: ${liquiditypool}`);
      contractversion === 1
        ? await approveLiquidityPoolAndMapAdapter(owner, registryContract, adapter, liquiditypool)
        : await approveLiquidityPoolAndMapAdapterV2(owner, registryContract, adapter, liquiditypool, checkapproval);
      console.log(`Finished mapping liquidity pool to adapter`);
    } catch (error) {
      console.error(`${TASKS.ACTION_TASKS.MAP_LIQUIDITYPOOL_TO_ADAPTER.NAME}: `, error);
      throw error;
    }
  });
