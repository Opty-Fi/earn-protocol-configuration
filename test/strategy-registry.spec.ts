import chai, { expect, assert } from "chai";
import { solidity } from "ethereum-waffle";
import hre from "hardhat";
import { BigNumber, Contract, ethers, Signer } from "ethers";
import { smock } from "@defi-wonderland/smock";
import { TypedStrategies, TypedTokens } from "../helpers/data";
import { TESTING_DEPLOYMENT_ONCE } from "../helpers/constants/utils";
import { ESSENTIAL_CONTRACTS } from "../helpers/constants/essential-contracts-name";
import scenario from "./scenarios/strategy-registry.spec.json";
import { deployContract, deploySmockContract, generateStrategyHashV2 } from "../helpers/helpers";

chai.use(solidity);

type ARGUMENTS = {
  mismatchLength?: boolean;
};

describe(scenario.title, async () => {
  let strategyRegistryContract: Contract;
  let ownerAddress: string;
  let users: { [key: string]: Signer } = {};
  const usedStrategy = TypedStrategies.filter(strategy => strategy.strategyName === "DAI-deposit-COMPOUND-cDAI")[0]
    .strategy;
  const usedStrategy_2 = TypedStrategies.filter(strategy => strategy.strategyName === "DAI-deposit-AAVE-aDAI")[0]
    .strategy;
  const convertedStrategies = usedStrategy.map(strategy => [strategy.contract, strategy.outputToken, strategy.isSwap]);
  const convertedStrategies_2 = usedStrategy_2.map(strategy => [
    strategy.contract,
    strategy.outputToken,
    strategy.isSwap,
  ]);
  const usedToken = TypedTokens["DAI"];
  let usedStrategyHash: string;
  before(async () => {
    try {
      usedStrategyHash = generateStrategyHashV2(usedStrategy, usedToken);
      const [owner, user1] = await hre.ethers.getSigners();
      users = { owner, user1 };
      ownerAddress = await owner.getAddress();
      const registryContract = await deploySmockContract(smock, ESSENTIAL_CONTRACTS.REGISTRY, []);
      registryContract.getOperator.returns(ownerAddress);
      strategyRegistryContract = await deployContract(
        hre,
        ESSENTIAL_CONTRACTS.STRATEGY_REGISTRY,
        TESTING_DEPLOYMENT_ONCE,
        owner,
        [registryContract.address],
      );

      assert.isDefined(registryContract, "Registry contract not deployed");
      assert.isDefined(strategyRegistryContract, "investStrategyRegistry contract not deployed");
    } catch (error) {
      console.log(error);
    }
  });

  for (let i = 0; i < scenario.stories.length; i++) {
    const story = scenario.stories[i];
    it(story.description, async () => {
      for (let i = 0; i < story.setActions.length; i++) {
        const action = story.setActions[i];
        switch (action.action) {
          case "addStrategy(bytes32,(address,address,bool)[],((bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256)))": {
            if (action.expect === "success") {
              const tx = await strategyRegistryContract
                .connect(users[action.executer])
                [action.action](usedStrategyHash, convertedStrategies, [
                  [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                  [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                  [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                  [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                  [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                  [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                  [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                  [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                ]);
              await tx.wait(1);
            } else {
              await expect(
                strategyRegistryContract
                  .connect(users[action.executer])
                  [action.action](usedStrategyHash, convertedStrategies, [
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                  ]),
              ).to.be.revertedWith(action.message);
            }
            break;
          }
          case "addStrategies(bytes32[],(address,address,bool)[][])": {
            const { mismatchLength }: ARGUMENTS = action.args;
            if (action.expect === "success") {
              const tx = await strategyRegistryContract
                .connect(users[action.executer])
                [action.action]([usedStrategyHash], [convertedStrategies]);
              await tx.wait(1);
            } else {
              await expect(
                strategyRegistryContract
                  .connect(users[action.executer])
                  [action.action](
                    [usedStrategyHash],
                    mismatchLength ? [convertedStrategies, convertedStrategies_2] : [convertedStrategies],
                  ),
              ).to.be.revertedWith(action.message);
            }
            break;
          }
          case "deleteStrategy(bytes32)": {
            if (action.expect === "success") {
              const tx = await strategyRegistryContract
                .connect(users[action.executer])
                [action.action](usedStrategyHash);
              await tx.wait(1);
              expect((await strategyRegistryContract.getStrategySteps(usedStrategyHash)).length).to.eq(0);
            } else {
              await expect(
                strategyRegistryContract.connect(users[action.executer])[action.action](usedStrategyHash),
              ).to.be.revertedWith(action.message);
            }
            break;
          }
          case "deleteStrategies(bytes32[])": {
            if (action.expect === "success") {
              const tx = await strategyRegistryContract
                .connect(users[action.executer])
                [action.action]([usedStrategyHash]);
              await tx.wait(1);
              expect((await strategyRegistryContract.getStrategySteps(usedStrategyHash)).length).to.eq(0);
            } else {
              await expect(
                strategyRegistryContract.connect(users[action.executer])[action.action]([usedStrategyHash]),
              ).to.be.revertedWith(action.message);
            }
            break;
          }
          default:
            break;
        }
      }

      for (let i = 0; i < story.getActions.length; i++) {
        const action = story.getActions[i];
        switch (action.action) {
          case "getStrategySteps(bytes32)": {
            const actualSteps = await strategyRegistryContract[action.action](usedStrategyHash);
            expect(actualSteps).to.deep.eq(convertedStrategies);
            break;
          }
          case "getOraValueUTPlan(bytes32)": {
            const actualOraValueUTPlan = await strategyRegistryContract[action.action](usedStrategyHash);
            expect(actualOraValueUTPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getOraValueLPPlan(bytes32)": {
            const actualOraValueLPPlan = await strategyRegistryContract[action.action](usedStrategyHash);
            expect(actualOraValueLPPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getLastStepBalanceLPPlan(bytes32)": {
            const actualLastStepBalanceLPPlan = await strategyRegistryContract[action.action](usedStrategyHash);
            expect(actualLastStepBalanceLPPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getDepositSomeToStrategyPlan(bytes32)": {
            const actualDepositSomeToStrategyPlan = await strategyRegistryContract[action.action](usedStrategyHash);
            expect(actualDepositSomeToStrategyPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getDepositAllToStrategyPlan(bytes32)": {
            const actualDepositAllToStrategyPlan = await strategyRegistryContract[action.action](usedStrategyHash);
            expect(actualDepositAllToStrategyPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getWithdrawSomeFromStrategyPlan(bytes32)": {
            const actualWithdrawSomeFromStrategyPlan = await strategyRegistryContract[action.action](usedStrategyHash);
            expect(actualWithdrawSomeFromStrategyPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getWithdrawAllFromStrategyPlan(bytes32)": {
            const actualWithdrawAllFromStrategyPlan = await strategyRegistryContract[action.action](usedStrategyHash);
            expect(actualWithdrawAllFromStrategyPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getClaimRewardsPlan(bytes32)": {
            const actualClaimRewardsPlan = await strategyRegistryContract[action.action](usedStrategyHash);
            expect(actualClaimRewardsPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          default:
            break;
        }
      }
    });
  }
});
