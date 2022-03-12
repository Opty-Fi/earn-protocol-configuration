import chai, { expect, assert } from "chai";
import { solidity } from "ethereum-waffle";
import hre from "hardhat";
import { Signer, Contract } from "ethers";
import { smock } from "@defi-wonderland/smock";
import { MOCK_CONTRACTS } from "../helpers/type";
import { TypedStrategies, TypedTokens } from "../helpers/data";
import { generateTokenHash, executeFunc, deploySmockContract, deployContract } from "../helpers/helpers";
import { TESTING_DEPLOYMENT_ONCE } from "../helpers/constants/utils";
import { ESSENTIAL_CONTRACTS } from "../helpers/constants/essential-contracts-name";
import { TESTING_CONTRACTS } from "../helpers/constants/test-contracts-name";
import { deployRegistry, deployRiskManager } from "../helpers/contracts-deployments";
import { approveAndMapTokenHashToToken, addRiskProfile } from "../helpers/contracts-actions";
import scenario from "./scenarios/risk-manager.json";
import { RISK_PROFILES } from "../helpers/constants/contracts-data";
import { NETWORKS_ID } from "../helpers/constants/network";
chai.use(solidity);

type ARGUMENTS = {
  canBorrow?: boolean;
  poolRatingRange?: number[];
  score?: number[];
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
      RISK_PROFILES[1].canBorrow,
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
            case "become(address)": {
              const newRiskManager = await deployContract(
                hre,
                TESTING_CONTRACTS.TEST_RISK_MANAGER_NEW_IMPLEMENTATION,
                TESTING_DEPLOYMENT_ONCE,
                owner,
                [registry.address],
              );

              const riskManagerProxy = await hre.ethers.getContractAt(
                ESSENTIAL_CONTRACTS.RISK_MANAGER_PROXY,
                riskManager.address,
              );

              await executeFunc(riskManagerProxy, owner, "setPendingImplementation(address)", [newRiskManager.address]);
              await executeFunc(newRiskManager, owner, "become(address)", [riskManagerProxy.address]);

              riskManager = await hre.ethers.getContractAt(
                TESTING_CONTRACTS.TEST_RISK_MANAGER_NEW_IMPLEMENTATION,
                riskManagerProxy.address,
              );
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
        for (let i = 0; i < story.cleanActions.length; i++) {
          const action = story.cleanActions[i];
          switch (action.action) {
            case "deployRiskManager()": {
              riskManager = await deployRiskManager(hre, owner, TESTING_DEPLOYMENT_ONCE, registry.address);
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
      const returnedStrategy = strategy.strategy.map(item => [item.contract, item.outputToken, item.isBorrow]);
      const returnedDefaultStrategy = defaultStrategy.strategy.map(item => [
        item.contract,
        item.outputToken,
        item.isBorrow,
      ]);

      let isCheckDefault = false;
      describe(strategy.strategyName, () => {
        for (let i = 0; i < scenario.stories.length; i++) {
          const story = scenario.stories[i];
          const usedLps: string[] = [];
          it(`${story.description}`, async () => {
            for (let i = 0; i < story.setActions.length; i++) {
              const action = story.setActions[i];
              switch (action.action) {
                case "updateRPPoolRatings(uint256,(uint8,uint8))": {
                  const { poolRatingRange }: ARGUMENTS = action.args;
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
                case "approveLiquidityPool(address[])": {
                  const lpTokens = strategy.strategy.map(strategy => strategy.contract);
                  if (action.expect === "success") {
                    await registry[action.action](lpTokens);
                  } else {
                    await expect(contracts[action.contract][action.action](lpTokens)).to.be.revertedWith(
                      action.message,
                    );
                  }

                  usedLps.push(...lpTokens);
                  break;
                }
                case "rateLiquidityPool((address,uint8)[])": {
                  const { score }: ARGUMENTS = action.args;
                  if (score) {
                    const lpTokens = strategy.strategy.map(strategy => strategy.contract);
                    const pools = lpTokens.map((lp, i) => [lp, score[i]]);
                    if (action.expect === "success") {
                      await registry[action.action](pools);
                    } else {
                      await expect(await contracts[action.contract][action.action](pools)).to.be.revertedWith(
                        action.message,
                      );
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
                  const { score }: ARGUMENTS = action.args;
                  const scoredPools: [string, number][] = [];
                  if (score) {
                    for (let i = 0; i < defaultStrategy.strategy.length; i++) {
                      const strategy = defaultStrategy.strategy[i];
                      if (!usedLps.includes(strategy.contract)) {
                        await registry["approveLiquidityPool(address)"](strategy.contract);
                        usedLps.push(strategy.contract);
                      }
                      scoredPools.push([strategy.contract, score[i]]);
                    }
                    await registry["rateLiquidityPool((address,uint8)[])"](scoredPools);
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
                  expect(await riskManager[action.action](riskProfileCode, tokenHash)).to.eql(
                    action.expectedValue !== ""
                      ? action.expectedValue
                      : isCheckDefault
                      ? returnedDefaultStrategy
                      : returnedStrategy,
                  );
                  break;
                }
              }
            }
            for (let i = 0; i < story.cleanActions.length; i++) {
              const action = story.cleanActions[i];
              switch (action.action) {
                case "revokeLiquidityPool(address[])": {
                  if (usedLps.length > 0) {
                    await registry[action.action](usedLps);
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
