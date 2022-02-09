import { task, types } from "hardhat/config";
import { isAddress, generateTokenHashV2 } from "../../helpers/helpers";
import { RISK_PROFILES } from "../../helpers/constants/contracts-data";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import TASKS from "../task-names";
import { NETWORKS_ID } from "../../helpers/constants/network";

/**
 * strategy type structure
 *  [
 *    [contract,outputToken,isBorrow]
 *  ]
  Ex:
    [
      ["0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643","0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643",true]
    ]
 */

task(TASKS.ACTION_TASKS.SET_BEST_STRATEGY_V2.NAME, TASKS.ACTION_TASKS.SET_BEST_STRATEGY_V2.DESCRIPTION)
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
      const tokensHash = generateTokenHashV2([token], NETWORKS_ID.MAINNET);
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
      console.error(`${TASKS.ACTION_TASKS.SET_BEST_STRATEGY_V2.NAME}: `, error);
    }
  });
