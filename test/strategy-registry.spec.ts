import chai, { expect, assert } from "chai";
import { solidity } from "ethereum-waffle";
import hre from "hardhat";
import { Contract, Signer } from "ethers";
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
  const convertedStrategies = usedStrategy.map(strategy => [
    strategy.contract,
    strategy.outputToken,
    strategy.isBorrow,
  ]);
  const convertedStrategies_2 = usedStrategy_2.map(strategy => [
    strategy.contract,
    strategy.outputToken,
    strategy.isBorrow,
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
          case "getStrategy(bytes32)": {
            const { _index, _strategySteps } = await strategyRegistryContract[action.action](usedStrategyHash);
            expect(_index).to.be.equal(0);
            expect(_strategySteps[0][0]).to.be.equal(usedStrategy[0].contract);
            expect(_strategySteps[0][1]).to.be.equal(usedStrategy[0].outputToken);
            expect(_strategySteps[0][2]).to.be.equal(usedStrategy[0].isBorrow);
            break;
          }
          default:
            break;
        }
      }
    });
  }
});
