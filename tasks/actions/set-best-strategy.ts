import { task, types } from "hardhat/config";
import { isAddress, generateTokenHash } from "../../helpers/helpers";
import { RISK_PROFILES } from "../../helpers/constants/contracts-data";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import TASKS from "../task-names";
import { NETWORKS_ID } from "../../helpers/constants/network";

task(TASKS.ACTION_TASKS.SET_BEST_STRATEGY.NAME, TASKS.ACTION_TASKS.SET_BEST_STRATEGY.DESCRIPTION)
  .addParam("token", "the address of token", "", types.string)
  .addParam("strategy", "the string of strategy", "", types.string)
  .addParam("riskprofilecode", "the code of risk profile", 0, types.int)
  .addParam("strategyprovider", "the address of strategyProvider", "", types.string)
  .addParam("isdefault", "whether set best default strategy or not", false, types.boolean)
  .setAction(async ({ token, riskprofilecode, strategy, strategyprovider, isdefault }, hre) => {
    if (strategyprovider === "") {
      throw new Error("strategyprovider cannot be empty");
    }

    if (!isAddress(strategyprovider)) {
      throw new Error("strategyprovider address is invalid");
    }

    if (token === "") {
      throw new Error("token cannot be empty");
    }

    if (!isAddress(token)) {
      throw new Error("token address is invalid");
    }

    if (RISK_PROFILES.filter(item => item.code === riskprofilecode).length === 0) {
      throw new Error("risk profile is not available");
    }

    const convertedStrategy = strategy.split("-").map((item: string) => item.split(","));
    console.log(convertedStrategy);
    try {
      const strategyProvider = await hre.ethers.getContractAt(ESSENTIAL_CONTRACTS.STRATEGY_PROVIDER, strategyprovider);
      const tokensHash = generateTokenHash([token], NETWORKS_ID.MAINNET);
      console.log(`Strategy : ${strategy}`);
      if (isdefault) {
        await strategyProvider.setBestDefaultStrategy(riskprofilecode, tokensHash, convertedStrategy);
        console.log(`Set best default strategy successfully`);
      } else {
        await strategyProvider.setBestStrategy(riskprofilecode, tokensHash, convertedStrategy);
        console.log(`Set best strategy successfully`);
      }
      console.log("Finished setting best strategy");
    } catch (error: any) {
      console.error(`${TASKS.ACTION_TASKS.SET_BEST_STRATEGY.NAME}: `, error);
    }
  });
