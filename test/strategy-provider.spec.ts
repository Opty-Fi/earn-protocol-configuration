import chai, { expect, assert } from "chai";
import hre from "hardhat";
import { Contract } from "ethers";
import { solidity } from "ethereum-waffle";
import { CONTRACTS } from "../helpers/type";
import { deployContract, generateTokenHash } from "../helpers/helpers";
import { TESTING_DEPLOYMENT_ONCE } from "../helpers/constants/utils";
import { ESSENTIAL_CONTRACTS } from "../helpers/constants/essential-contracts-name";
import { TESTING_CONTRACTS } from "../helpers/constants/test-contracts-name";
import { deployRegistry } from "../helpers/contracts-deployments";
import scenario from "./scenarios/strategy-provider.json";
import { approveAndMapTokenHashToTokens, addRiskProfile } from "../helpers/contracts-actions";
import { TypedStrategies, TypedTokens } from "../helpers/data";
import { RISK_PROFILES } from "../helpers/constants/contracts-data";
import { NETWORKS_ID } from "../helpers/constants/network";
chai.use(solidity);

type ARGUMENTS = {
  isSecond?: boolean;
  isEmpty?: boolean;
  riskProfileCode?: string;
  strategyName?: string;
  tokenName?: string;
  defaultStrategyState?: number;
  vaultRewardStrategy?: number[];
  newStrategyOperator?: string;
  isNonApprovedToken?: boolean;
};

describe(scenario.title, () => {
  let contracts: CONTRACTS = {};
  let signers: any;
  let DUMMY_VAULT_EMPTY_CONTRACT: Contract;
  let vaultRewardTokenHash: string;
  const usedToken = TypedTokens["DAI"];
  const nonApprovedToken = TypedTokens["USDC"];
  const usedTokenHash = generateTokenHash([usedToken], NETWORKS_ID.MAINNET);
  const nonApprovedTokenHash = generateTokenHash([nonApprovedToken], NETWORKS_ID.MAINNET);
  const usedStrategy = TypedStrategies.filter(strategy => strategy.token == "DAI")[0].strategy;
  const secondStrategy = TypedStrategies.filter(strategy => strategy.token == "DAI")[1].strategy;

  const riskProfile = RISK_PROFILES[1];
  before(async () => {
    try {
      const [owner, user1] = await hre.ethers.getSigners();
      const ownerAddress = await owner.getAddress();
      const strategyOperator = owner;
      signers = { owner, strategyOperator, user1 };
      const registry = await deployRegistry(hre, owner, TESTING_DEPLOYMENT_ONCE);
      DUMMY_VAULT_EMPTY_CONTRACT = await deployContract(
        hre,
        TESTING_CONTRACTS.TEST_DUMMY_EMPTY_CONTRACT,
        TESTING_DEPLOYMENT_ONCE,
        owner,
        [],
      );

      await addRiskProfile(
        registry,
        owner,
        riskProfile.code,
        riskProfile.name,
        riskProfile.symbol,
        riskProfile.poolRating,
      );

      await expect(registry["approveToken(address)"](usedToken))
        .to.emit(registry, "LogToken")
        .withArgs(hre.ethers.utils.getAddress(usedToken), true, ownerAddress);
      await expect(registry.connect(owner)["setTokensHashToTokens(bytes32,address[])"](usedTokenHash, [usedToken]))
        .to.emit(registry, "LogTokensToTokensHash")
        .withArgs(usedTokenHash, ownerAddress);
      const strategyProvider = await deployContract(
        hre,
        ESSENTIAL_CONTRACTS.STRATEGY_PROVIDER,
        TESTING_DEPLOYMENT_ONCE,
        owner,
        [registry.address],
      );

      const COMP_TOKEN = TypedTokens["COMP"];
      vaultRewardTokenHash = generateTokenHash([DUMMY_VAULT_EMPTY_CONTRACT.address, COMP_TOKEN], NETWORKS_ID.MAINNET);
      await approveAndMapTokenHashToTokens(
        signers["owner"],
        registry,
        [DUMMY_VAULT_EMPTY_CONTRACT.address, COMP_TOKEN],
        false,
        NETWORKS_ID.MAINNET,
        false,
      );
      contracts = { registry, strategyProvider };
    } catch (error: any) {
      console.log(error);
    }
  });

  for (let i = 0; i < scenario.stories.length; i++) {
    const story = scenario.stories[i];
    it(`${story.description}`, async () => {
      for (let i = 0; i < story.setActions.length; i++) {
        const action: any = story.setActions[i];
        await setAndCleanActions(action);
      }
      for (let i = 0; i < story.getActions.length; i++) {
        const action: any = story.getActions[i];
        switch (action.action) {
          case "getRpToTokenToDefaultStrategy(uint256,bytes32)":
          case "getRpToTokenToBestStrategy(uint256,bytes32)": {
            const { isEmpty, isSecond }: ARGUMENTS = action.args;
            const strategy = isSecond ? secondStrategy : usedStrategy;

            expect(
              await contracts[action.contract][action.action](
                riskProfile.code,
                generateTokenHash([usedToken], NETWORKS_ID.MAINNET),
              ),
            ).to.be.eqls(isEmpty ? [] : strategy.map(item => [item.contract, item.outputToken, item.isSwap]));

            break;
          }
          case "vaultRewardTokenHashToVaultRewardTokenStrategy(bytes32)": {
            const value = await contracts[action.contract][action.action](vaultRewardTokenHash);
            expect([+value[0]._hex, +value[1]._hex]).to.have.members(action.expectedValue.vaultRewardStrategy);
            break;
          }
        }
      }
      for (let i = 0; i < story.cleanActions.length; i++) {
        const action: any = story.cleanActions[i];
        await setAndCleanActions(action);
      }
    });
  }

  async function setAndCleanActions(action: any) {
    switch (action.action) {
      case "setStrategyOperator(address)": {
        const { newStrategyOperator }: ARGUMENTS = action.args;
        const tempNewStrategyOperatorAddr = await signers[<any>newStrategyOperator].getAddress();
        if (newStrategyOperator) {
          if (action.expect === "success") {
            await expect(
              contracts[action.contract].connect(signers[action.executor])[action.action](tempNewStrategyOperatorAddr),
            )
              .to.emit(contracts[action.contract], "TransferStrategyOperator")
              .withArgs(tempNewStrategyOperatorAddr, await signers[action.executor].getAddress());
          } else {
            await expect(
              contracts[action.contract].connect(signers[action.executor])[action.action](tempNewStrategyOperatorAddr),
            ).to.be.revertedWith(action.message);
          }
        }
        assert.isDefined(newStrategyOperator, `args is wrong in ${action.action} testcase`);
        break;
      }
      case "setVaultRewardStrategy(bytes32,(uint256,uint256))": {
        const { vaultRewardStrategy, isNonApprovedToken }: ARGUMENTS = action.args;
        if (Array.isArray(vaultRewardStrategy) && vaultRewardStrategy.length > 0) {
          if (action.expect === "success") {
            await contracts[action.contract]
              .connect(signers[action.executor])
              [action.action](vaultRewardTokenHash, vaultRewardStrategy);
          } else {
            await expect(
              contracts[action.contract]
                .connect(signers[action.executor])
                [action.action](isNonApprovedToken ? nonApprovedTokenHash : vaultRewardTokenHash, vaultRewardStrategy),
            ).to.be.revertedWith(action.message);
          }
        }
        assert.isDefined(vaultRewardStrategy, `args is wrong in ${action.action} testcase`);
        break;
      }
      case "setBestStrategy(uint256,bytes32,(address,address,bool)[])":
      case "setBestDefaultStrategy(uint256,bytes32,(address,address,bool)[])": {
        const { riskProfileCode, isNonApprovedToken, isEmpty, isSecond }: ARGUMENTS = action.args;
        if (riskProfileCode) {
          const strategy = isSecond ? secondStrategy : usedStrategy;
          if (action.expect === "success") {
            await contracts[action.contract]
              .connect(signers[action.executor])
              [action.action](
                riskProfileCode,
                usedTokenHash,
                isEmpty ? [] : strategy.map(item => [item.contract, item.outputToken, item.isSwap]),
              );
          } else {
            await expect(
              contracts[action.contract].connect(signers[action.executor])[action.action](
                riskProfileCode,
                isNonApprovedToken ? nonApprovedTokenHash : usedTokenHash,
                strategy.map(item => [item.contract, item.outputToken, item.isSwap]),
              ),
            ).to.be.revertedWith(action.message);
          }
        }
        assert.isDefined(riskProfileCode, `args is wrong in ${action.action} testcase`);
        break;
      }
    }
  }
});
