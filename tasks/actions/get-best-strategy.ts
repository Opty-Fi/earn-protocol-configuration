import { task, types } from "hardhat/config";
import { isAddress, generateTokenHash, generateTokenHashV2 } from "../../helpers/helpers";
import { RISK_PROFILES } from "../../helpers/constants/contracts-data";
import { ESSENTIAL_CONTRACTS } from "../../helpers/constants/essential-contracts-name";
import { NETWORKS_ID } from "../../helpers/constants/network";

import TASKS from "../task-names";

task(TASKS.ACTION_TASKS.GET_BEST_STRATEGY.NAME, TASKS.ACTION_TASKS.GET_BEST_STRATEGY.DESCRIPTION)
  .addParam("token", "the address of token", "", types.string)
  .addParam("riskprofilecode", "the code of risk profile", 0, types.int)
  .addParam("strategyprovider", "the address of strategyProvider", "", types.string)
  .addParam("isdefault", "get default strategy or not", false, types.boolean)
  .addParam("contractversion", "the version of strategyProvider", 1, types.int)
  .setAction(async ({ token, riskprofilecode, strategyprovider, isdefault, contractversion }, hre) => {
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

    if (contractversion !== 1 && contractversion !== 2) {
      throw new Error("contractversion is invalid");
    }

    try {
      const strategyProvider = await hre.ethers.getContractAt(
        contractversion === 1 ? ESSENTIAL_CONTRACTS.STRATEGY_PROVIDER : ESSENTIAL_CONTRACTS.STRATEGY_PROVIDER_V2,
        strategyprovider,
      );
      const tokensHash =
        contractversion === 1 ? generateTokenHash([token]) : generateTokenHashV2([token], NETWORKS_ID.MAINNET);
      let strategyHash = "";
      if (contractversion === 1) {
        if (isdefault) {
          strategyHash = await strategyProvider.rpToTokenToDefaultStrategy(riskprofilecode, tokensHash);
        } else {
          strategyHash = await strategyProvider.rpToTokenToBestStrategy(riskprofilecode, tokensHash);
        }
      } else {
        if (isdefault) {
          strategyHash = await strategyProvider.getRpToTokenToDefaultStrategy(riskprofilecode, tokensHash);
        } else {
          strategyHash = await strategyProvider.getRpToTokenToBestStrategy(riskprofilecode, tokensHash);
        }
      }

      console.log(`StrategyHash : ${strategyHash}`);
    } catch (error: any) {
      console.error(`${TASKS.ACTION_TASKS.GET_BEST_STRATEGY.NAME}: `, error);
      throw error;
    }
  });
