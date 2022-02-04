import { task, types } from "hardhat/config";
import { isAddress, generateTokenHash } from "../../helpers/helpers";
import { RISK_PROFILES } from "../../helpers/constants/contracts-data";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import { SET_BEST_STRATEGY } from "../task-names";
import { NETWORKS_ID } from "../../helpers/constants/network";
import fs from "fs";

/**
 * best-strategy.json structure
 *  [contract,outputToken,isBorrow]
  Ex:
    ["0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643","0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643",true]
 */

task(SET_BEST_STRATEGY, "Set best strategy")
  .addParam("token", "the address of token", "", types.string)
  .addParam("fromfile", "path to best strategy json file", "", types.string)
  .addParam("riskprofilecode", "the code of risk profile", 0, types.int)
  .addParam("strategyprovider", "the address of strategyProvider", "", types.string)
  .addParam("isdefault", "whether set best default strategy or not", false, types.boolean)
  .setAction(async ({ token, riskprofilecode, fromfile, strategyprovider, isdefault }, hre) => {
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

    if (!fromfile) {
      throw new Error("best strategy file is required");
    }

    const content = fs.readFileSync(fromfile);
    const strategy: string[] = JSON.parse(content.toString());

    try {
      const strategyProvider = await hre.ethers.getContractAt(ESSENTIAL_CONTRACTS.STRATEGY_PROVIDER, strategyprovider);
      const tokensHash = generateTokenHash([token], NETWORKS_ID.MAINNET);
      console.log(`Strategy : ${strategy}`);
      if (isdefault) {
        await strategyProvider.setBestDefaultStrategy(riskprofilecode, tokensHash, strategy);
        console.log(`Set best default strategy successfully`);
      } else {
        await strategyProvider.setBestStrategy(riskprofilecode, tokensHash, strategy);
        console.log(`Set best strategy successfully`);
      }
      console.log("Finished setting best strategy");
    } catch (error: any) {
      console.error(`${SET_BEST_STRATEGY}: `, error);
    }
  });
