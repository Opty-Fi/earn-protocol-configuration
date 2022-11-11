import chai, { expect, assert } from "chai";
import { solidity } from "ethereum-waffle";
import hre from "hardhat";
import { Signer, Contract } from "ethers";
import { smock } from "@defi-wonderland/smock";
import { MOCK_CONTRACTS } from "../helpers/type";
import { TypedStrategies, TypedTokens } from "../helpers/data";
import { generateTokenHash, executeFunc, deploySmockContract } from "../helpers/helpers";
import { TESTING_DEPLOYMENT_ONCE } from "../helpers/constants/utils";
import { ESSENTIAL_CONTRACTS } from "../helpers/constants/essential-contracts-name";
import { deployRegistry, deployRiskManager } from "../helpers/contracts-deployments";
import { approveAndMapTokenHashToToken, addRiskProfile } from "../helpers/contracts-actions";
import scenario from "./scenarios/risk-manager.json";
import { RISK_PROFILES } from "../helpers/constants/contracts-data";
import { NETWORKS_ID } from "../helpers/constants/network";
chai.use(solidity);

type ARGUMENTS = {
  canBorrow?: boolean;
  poolRatingRange?: number[];
  score?: number;
  defaultStrategyState?: number;
  riskProfileCode?: string;
};

describe(scenario.title, () => {
  let registry: Contract;
  let riskManager: Contract;
  const riskProfileCode = "1";
  let owner: Signer;

  before(async () => {
    [owner] = await hre.ethers.getSigners();
    registry = await deployRegistry(hre, owner, TESTING_DEPLOYMENT_ONCE);

    riskManager = await deployRiskManager(hre, owner, TESTING_DEPLOYMENT_ONCE, registry.address);

    await addRiskProfile(
      registry,
      owner,
      RISK_PROFILES[1].code,
      RISK_PROFILES[1].name,
      RISK_PROFILES[1].symbol,
      RISK_PROFILES[1].poolRating,
    );
    //Initialize data for tokensHashIndexes
    await approveAndMapTokenHashToToken(owner, registry, TypedTokens["SUSD"], NETWORKS_ID.MAINNET, false);
  });

  describe("Standalone Scenarios", () => {
    const usedToken = TypedTokens["USDT"];
    const tokenHash = generateTokenHash([usedToken], NETWORKS_ID.MAINNET);
    for (let i = 0; i < scenario.standaloneStories.length; i++) {
      const story = scenario.standaloneStories[i];
      it(story.description, async () => {
        for (let i = 0; i < story.setActions.length; i++) {
          const action = story.setActions[i];
          switch (action.action) {
            case "approveAndMapTokenHashToToken(bytes32,address[])": {
              await approveAndMapTokenHashToToken(owner, registry, usedToken, NETWORKS_ID.MAINNET, false);
              break;
            }
            case "revokeToken(address[])": {
              await registry[action.action]([usedToken]);
              break;
            }
          }
        }
        for (let i = 0; i < story.getActions.length; i++) {
          const action = story.getActions[i];
          switch (action.action) {
            case "isNewContract()": {
              expect(await riskManager[action.action]()).to.be.equal(action.expectedValue);
              break;
            }
            case "getBestStrategy(uint256,bytes32)": {
              const { riskProfileCode }: ARGUMENTS = action.args;
              await expect(riskManager[action.action](riskProfileCode, tokenHash)).to.be.revertedWith(
                action.expectedValue.toString(),
              );
              break;
            }
          }
        }
      });
    }
  });

  describe("Integration Scenarios", () => {
    let contracts: MOCK_CONTRACTS = {};

    before(async () => {
      const strategyProvider = await deploySmockContract(smock, ESSENTIAL_CONTRACTS.STRATEGY_PROVIDER, [
        registry.address,
      ]);
      contracts = { strategyProvider };
      await executeFunc(registry, owner, "setStrategyProvider(address)", [strategyProvider.address]);
      const usedTokens = TypedStrategies.map(item => item.token).filter(
        (value, index, self) => self.indexOf(value) === index,
      );
      for (let i = 0; i < usedTokens.length; i++) {
        try {
          await approveAndMapTokenHashToToken(
            owner,
            registry,
            TypedTokens[usedTokens[i].toUpperCase()],
            NETWORKS_ID.MAINNET,
            false,
          );
        } catch (error) {
          continue;
        }
      }
    });
    for (let i = 0; i < TypedStrategies.length; i++) {
      const strategy = TypedStrategies[i];
      const tokenHash = generateTokenHash([TypedTokens[strategy.token.toUpperCase()]], NETWORKS_ID.MAINNET);

      const defaultStrategy = TypedStrategies.filter(
        item => item.token === strategy.token && item.strategyName !== strategy.strategyName,
      )[0];
      if (!defaultStrategy) {
        continue;
      }
      const returnedStrategy = strategy.strategy.map(item => ({
        pool: item.contract,
        outputToken: item.outputToken,
        isSwap: item.isSwap,
      }));
      const returnedDefaultStrategy = defaultStrategy.strategy.map(item => ({
        pool: item.contract,
        outputToken: item.outputToken,
        isSwap: item.isSwap,
      }));

      let isCheckDefault = false;
      describe(strategy.strategyName, () => {
        for (let i = 0; i < scenario.stories.length; i++) {
          const story = scenario.stories[i];
          const usedLiquidityPools: string[] = [];
          const usedSwapPools: string[] = [];
          it(`${story.description}`, async () => {
            for (let i = 0; i < story.setActions.length; i++) {
              const action = story.setActions[i];
              switch (action.action) {
                case "updateRPPoolRatings(uint256,(uint8,uint8))": {
                  const { poolRatingRange } = <ARGUMENTS>action.args;
                  if (riskProfileCode && poolRatingRange) {
                    const value = await registry.getRiskProfile(riskProfileCode);
                    const riskProfileIndex = value.index;
                    await expect(registry[action.action](riskProfileCode, poolRatingRange))
                      .to.emit(registry, "LogRPPoolRatings")
                      .withArgs(riskProfileIndex, poolRatingRange[0], poolRatingRange[1], await owner.getAddress());
                  }
                  assert.isDefined(poolRatingRange, `args is wrong in ${action.action} testcase`);
                  break;
                }
                case "approvePool": {
                  const liquidityPools = strategy.strategy
                    .filter(strategy => !strategy.isSwap)
                    .map(strategy => strategy.contract);
                  const swapPools = strategy.strategy
                    .filter(strategy => strategy.isSwap)
                    .map(strategy => strategy.contract);
                  if (action.expect === "success") {
                    if (liquidityPools.length > 0) {
                      await registry["approveLiquidityPool(address[])"](liquidityPools);
                    }
                    if (swapPools.length > 0) {
                      await registry["approveSwapPool(address[])"](swapPools);
                    }
                  } else {
                    if (liquidityPools.length > 0) {
                      await expect(registry["approveLiquidityPool(address[])"](liquidityPools)).to.be.revertedWith(
                        action.message,
                      );
                    }
                    if (swapPools.length > 0) {
                      await expect(registry["approveSwapPool(address[])"](swapPools)).to.be.revertedWith(
                        action.message,
                      );
                    }
                  }

                  if (liquidityPools.length > 0) {
                    usedLiquidityPools.push(...(liquidityPools as string[]));
                  }
                  if (swapPools.length > 0) {
                    usedSwapPools.push(...(swapPools as string[]));
                  }
                  break;
                }
                case "ratePool": {
                  const { score } = <ARGUMENTS>action.args;
                  if (score) {
                    const liquidityPools = strategy.strategy
                      .filter(strategy => !strategy.isSwap)
                      .map(strategy => strategy.contract);
                    const swapPools = strategy.strategy
                      .filter(strategy => strategy.isSwap)
                      .map(strategy => strategy.contract);
                    const liquidityPoolWithRatings = liquidityPools.map(lp => [lp, score]);
                    const swapPoolWithRatings = swapPools.map(lp => [lp, score]);
                    if (action.expect === "success") {
                      if (liquidityPoolWithRatings.length > 0) {
                        await registry["rateLiquidityPool((address,uint8)[])"](liquidityPoolWithRatings);
                      }
                      if (swapPoolWithRatings.length > 0) {
                        await registry["rateSwapPool((address,uint8)[])"](swapPoolWithRatings);
                      }
                    } else {
                      if (liquidityPoolWithRatings.length > 0) {
                        await expect(
                          registry["rateLiquidityPool((address,uint8)[])"](liquidityPoolWithRatings),
                        ).to.be.revertedWith(action.message);
                      }
                      if (swapPoolWithRatings.length > 0) {
                        await expect(
                          registry["rateSwapPool((address,uint8)[])"](swapPoolWithRatings),
                        ).to.be.revertedWith(action.message);
                      }
                    }
                  }
                  assert.isDefined(score, `args is wrong in ${action.action} testcase`);
                  break;
                }
                case "setBestStrategy(uint256,bytes32,(address,address,bool)[])": {
                  contracts[action.contract].getRpToTokenToBestStrategy.returns(returnedStrategy);
                  break;
                }
                case "setBestDefaultStrategy(uint256,bytes32,(address,address,bool)[])": {
                  const { score } = <ARGUMENTS>action.args;
                  const scoredLiquidityPools: [string, number][] = [];
                  const scoredSwapPools: [string, number][] = [];
                  if (score) {
                    for (let i = 0; i < defaultStrategy.strategy.length; i++) {
                      const strategy = defaultStrategy.strategy[i];
                      if (!strategy.isSwap) {
                        if (!usedLiquidityPools.includes(strategy.contract)) {
                          await registry["approveLiquidityPool(address)"](strategy.contract);
                          usedLiquidityPools.push(strategy.contract);
                        }
                        scoredLiquidityPools.push([strategy.contract, score]);
                        await registry["rateLiquidityPool((address,uint8)[])"](scoredLiquidityPools);
                      }
                      if (strategy.isSwap) {
                        if (!usedSwapPools.includes(strategy.contract)) {
                          await registry["approveSwapPool(address)"](strategy.contract);
                          usedSwapPools.push(strategy.contract);
                        }
                        scoredSwapPools.push([strategy.contract, score]);
                        await registry["rateSwapPool((address,uint8)[])"](scoredSwapPools);
                      }
                    }
                  }
                  contracts[action.contract].getRpToTokenToDefaultStrategy.returns(returnedDefaultStrategy);
                  isCheckDefault = true;
                  assert.isDefined(score, `args is wrong in ${action.action} testcase`);
                  break;
                }
              }
            }
            for (let i = 0; i < story.getActions.length; i++) {
              const action = story.getActions[i];
              switch (action.action) {
                case "getBestStrategy(uint256,bytes32)": {
                  const steps =
                    action.expectedValue !== ""
                      ? action.expectedValue
                      : isCheckDefault
                      ? returnedDefaultStrategy
                      : returnedStrategy;
                  expect(await riskManager[action.action](riskProfileCode, tokenHash)).to.deep.eq(
                    (steps as { pool: string; outputToken: string; isSwap: boolean }[]).map(item =>
                      Object.values(item),
                    ),
                  );
                  break;
                }
              }
            }
            for (let i = 0; i < story.cleanActions.length; i++) {
              const action = story.cleanActions[i];
              switch (action.action) {
                case "revokePool": {
                  if (usedLiquidityPools.length > 0) {
                    await registry["revokeLiquidityPool(address[])"](usedLiquidityPools);
                  }
                  if (usedSwapPools.length > 0) {
                    await registry["revokeSwapPool(address[])"](usedSwapPools);
                  }
                  break;
                }
                case "setBestStrategy(uint256,bytes32,(address,address,bool)[])": {
                  contracts[action.contract].getRpToTokenToBestStrategy.returns([]);
                  break;
                }
                case "setBestDefaultStrategy(uint256,bytes32,(address,address,bool)[])": {
                  contracts[action.contract].getRpToTokenToDefaultStrategy.returns([]);
                  isCheckDefault = false;
                  break;
                }
              }
            }
          });
        }
      });
    }
  });
});
