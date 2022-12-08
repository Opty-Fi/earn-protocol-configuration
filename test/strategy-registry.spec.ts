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
  let usedStrategyHash_2: string;
  let mockVault: Contract;
  before(async () => {
    try {
      usedStrategyHash = generateStrategyHashV2(usedStrategy, usedToken);
      usedStrategyHash_2 = generateStrategyHashV2(usedStrategy_2, usedToken);
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

      mockVault = await deployContract(hre, "TestDummyEmptyContract", TESTING_DEPLOYMENT_ONCE, owner, []);

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
          case "addStrategy(bytes32,(address,address,bool)[])": {
            if (action.expect === "success") {
              const tx = await strategyRegistryContract
                .connect(users[action.executer])
                [action.action](usedStrategyHash, convertedStrategies);
              await tx.wait(1);
            } else {
              await expect(
                strategyRegistryContract
                  .connect(users[action.executer])
                  [action.action](usedStrategyHash, convertedStrategies),
              ).to.be.revertedWith(action.message);
            }
            break;
          }
          case "addStrategyPlan(address,bytes32,((bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256)))": {
            if (action.expect === "success") {
              const tx = await strategyRegistryContract
                .connect(users[action.executer])
                [action.action](mockVault.address, usedStrategyHash, [
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
                  [action.action](mockVault.address, usedStrategyHash, [
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
          case "addStrategyPlans(address[],bytes32[],((bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256),(bytes32[],bytes[],uint256))[])": {
            const { mismatchLength }: ARGUMENTS = action.args;
            if (action.expect === "success") {
              const tx = await strategyRegistryContract.connect(users[action.executer])[action.action](
                [mockVault.address],
                [usedStrategyHash],
                [
                  [
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                    [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                  ],
                ],
              );
              await tx.wait(1);
            } else {
              await expect(
                strategyRegistryContract
                  .connect(users[action.executer])
                  [action.action](
                    [mockVault.address],
                    mismatchLength ? [usedStrategyHash, usedStrategyHash_2] : [usedStrategyHash],
                    [
                      [
                        [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                        [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                        [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                        [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                        [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                        [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                        [[ethers.utils.formatBytes32String("abc")], ["0xabcd1234"], 0],
                      ],
                    ],
                  ),
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
          case "getOraValueUTPlan(address,bytes32)": {
            const actualOraValueUTPlan = await strategyRegistryContract[action.action](
              mockVault.address,
              usedStrategyHash,
            );
            expect(actualOraValueUTPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getOraValueLPPlan(address,bytes32)": {
            const actualOraValueLPPlan = await strategyRegistryContract[action.action](
              mockVault.address,
              usedStrategyHash,
            );
            expect(actualOraValueLPPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getLastStepBalanceLPPlan(address,bytes32)": {
            const actualLastStepBalanceLPPlan = await strategyRegistryContract[action.action](
              mockVault.address,
              usedStrategyHash,
            );
            expect(actualLastStepBalanceLPPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getDepositSomeToStrategyPlan(address,bytes32)": {
            const actualDepositSomeToStrategyPlan = await strategyRegistryContract[action.action](
              mockVault.address,
              usedStrategyHash,
            );
            expect(actualDepositSomeToStrategyPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getWithdrawSomeFromStrategyPlan(address,bytes32)": {
            const actualWithdrawSomeFromStrategyPlan = await strategyRegistryContract[action.action](
              mockVault.address,
              usedStrategyHash,
            );
            expect(actualWithdrawSomeFromStrategyPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getClaimRewardsPlan(address,bytes32)": {
            const actualClaimRewardsPlan = await strategyRegistryContract[action.action](
              mockVault.address,
              usedStrategyHash,
            );
            expect(actualClaimRewardsPlan).to.deep.eq([
              [ethers.utils.formatBytes32String("abc")],
              ["0xabcd1234"],
              BigNumber.from(0),
            ]);
            break;
          }
          case "getHarvestRewardsPlan(address,bytes32)": {
            const actualClaimRewardsPlan = await strategyRegistryContract[action.action](
              mockVault.address,
              usedStrategyHash,
            );
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
