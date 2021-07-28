import { expect, assert } from "chai";
import hre from "hardhat";
import { Contract, Signer, BigNumber } from "ethers";
import { setUp } from "./setup";
import { CONTRACTS } from "../../helpers/type";
import { TOKENS, TESTING_DEPLOYMENT_ONCE, REWARD_TOKENS } from "../../helpers/constants";
import { TypedAdapterStrategies } from "../../helpers/data";
import { getSoliditySHA3Hash } from "../../helpers/utils";
import { deployVault } from "../../helpers/contracts-deployments";
import {
  setBestBasicStrategy,
  approveLiquidityPoolAndMapAdapter,
  fundWalletToken,
  getBlockTimestamp,
  getTokenName,
  getTokenSymbol,
  approveVaultRewardTokens,
  unpauseVault,
} from "../../helpers/contracts-actions";
import scenario from "./scenarios/get-price-per-share-write.json";
import { getContractInstance } from "../../helpers/helpers";

type ARGUMENTS = {
  addressName?: string;
  amount?: { [key: string]: string };
  defaultAmount?: string;
  hold?: number;
  convert?: number;
  vaultRewardStrategy?: number[];
  vaultRewardTokenInvalidHash?: string;
};

describe(scenario.title, () => {
  // TODO: ADD TEST SCENARIOES, ADVANCED PROFILE, STRATEGIES.
  let essentialContracts: CONTRACTS;
  let adapters: CONTRACTS;
  const contracts: CONTRACTS = {};
  let users: { [key: string]: Signer };
  before(async () => {
    try {
      const [owner, admin, user1] = await hre.ethers.getSigners();
      users = { owner, admin, user1 };
      [essentialContracts, adapters] = await setUp(users["owner"]);
      assert.isDefined(essentialContracts, "Essential contracts not deployed");
      assert.isDefined(adapters, "Adapters not deployed");
    } catch (error) {
      console.log(error);
    }
  });

  for (let i = 0; i < scenario.vaults.length; i++) {
    describe(`${scenario.vaults[i].name}`, async () => {
      let Vault: Contract;
      const vault = scenario.vaults[i];
      const profile = vault.profile;
      const ADAPTER_NAME = "CurveDepositPoolAdapter";
      const strategies = TypedAdapterStrategies[ADAPTER_NAME];
      for (let i = 0; i < strategies.length; i++) {
        describe(`${strategies[i].strategyName}`, async () => {
          const TOKEN_STRATEGY = strategies[i];
          const tokensHash = getSoliditySHA3Hash(["address[]"], [[TOKENS[TOKEN_STRATEGY.token]]]);
          const rewardTokenAdapterNames = Object.keys(REWARD_TOKENS).map(rewardTokenAdapterName =>
            rewardTokenAdapterName.toLowerCase(),
          );
          let underlyingTokenName: string;
          let underlyingTokenSymbol: string;
          let RewardToken_ERC20Instance: any;

          before(async () => {
            underlyingTokenName = await getTokenName(hre, TOKEN_STRATEGY.token);
            underlyingTokenSymbol = await getTokenSymbol(hre, TOKEN_STRATEGY.token);
            const adapter = adapters[ADAPTER_NAME];
            Vault = await deployVault(
              hre,
              essentialContracts.registry.address,
              TOKENS[TOKEN_STRATEGY.token],
              users["owner"],
              users["admin"],
              underlyingTokenName,
              underlyingTokenSymbol,
              profile,
              TESTING_DEPLOYMENT_ONCE,
            );
            await unpauseVault(users["owner"], essentialContracts.registry, Vault.address, true);

            if (rewardTokenAdapterNames.includes(ADAPTER_NAME.toLowerCase())) {
              await approveVaultRewardTokens(
                users["owner"],
                Vault.address,
                <string>REWARD_TOKENS[ADAPTER_NAME].tokenAddress,
                essentialContracts.registry,
              );
              RewardToken_ERC20Instance = await getContractInstance(
                hre,
                "ERC20",
                <string>REWARD_TOKENS[ADAPTER_NAME].tokenAddress,
              );
            }

            await approveLiquidityPoolAndMapAdapter(
              users["owner"],
              essentialContracts.registry,
              adapter.address,
              TOKEN_STRATEGY.strategy[0].contract,
            );

            await setBestBasicStrategy(
              TOKEN_STRATEGY.strategy,
              tokensHash,
              essentialContracts.vaultStepInvestStrategyDefinitionRegistry,
              essentialContracts.strategyProvider,
              profile,
            );

            const Token_ERC20Instance = await getContractInstance(hre, "ERC20", TOKENS[TOKEN_STRATEGY.token]);
            contracts["vault"] = Vault;
            contracts["registry"] = essentialContracts.registry;
            contracts["tokenErc20"] = Token_ERC20Instance;
            contracts["rewardTokenErc20"] = RewardToken_ERC20Instance;
            contracts["adapter"] = adapter;
            contracts["strategyProvider"] = essentialContracts.strategyProvider;
            contracts["riskManager"] = essentialContracts.riskManager;
          });

          for (let i = 0; i < vault.stories.length; i++) {
            const story = vault.stories[i];
            it(story.description, async () => {
              for (let j = 0; j < story.setActions.length; j++) {
                const action = story.setActions[j];
                switch (action.action) {
                  case "fundWallet": {
                    const { addressName, amount }: ARGUMENTS = action.args;
                    try {
                      if (addressName && amount) {
                        const timestamp = (await getBlockTimestamp(hre)) * 2;
                        await fundWalletToken(
                          hre,
                          TOKENS[TOKEN_STRATEGY.token],
                          users[addressName],
                          BigNumber.from(amount[TOKEN_STRATEGY.token]),
                          timestamp,
                        );
                      }
                    } catch (error) {
                      if (action.expect === "success") {
                        assert.isUndefined(error);
                      } else {
                        expect(error.message).to.equal(
                          `VM Exception while processing transaction: revert ${action.message}`,
                        );
                      }
                    }
                    assert.isDefined(addressName, `args is wrong in ${action.action} testcase`);
                    assert.isDefined(amount, `args is wrong in ${action.action} testcase`);
                    break;
                  }
                  case "approve(address,uint256)": {
                    const { addressName, amount }: ARGUMENTS = action.args;
                    try {
                      if (addressName && amount) {
                        await contracts[action.contract]
                          .connect(users[action.executer])
                          [action.action](contracts[addressName].address, amount[TOKEN_STRATEGY.token]);
                      }
                    } catch (error) {
                      if (action.expect === "success") {
                        assert.isUndefined(error);
                      } else {
                        expect(error.message).to.equal(
                          `VM Exception while processing transaction: revert ${action.message}`,
                        );
                      }
                    }
                    assert.isDefined(addressName, `args is wrong in ${action.action} testcase`);
                    assert.isDefined(amount, `args is wrong in ${action.action} testcase`);
                    break;
                  }
                  case "userDepositRebalance(uint256)": {
                    const { amount }: ARGUMENTS = action.args;
                    try {
                      if (amount) {
                        await contracts[action.contract]
                          .connect(users[action.executer])
                          [action.action](amount[TOKEN_STRATEGY.token]);
                      }
                    } catch (error) {
                      if (action.expect === "success") {
                        assert.isUndefined(error);
                      } else {
                        expect(error.message).to.equal(
                          `VM Exception while processing transaction: revert ${action.message}`,
                        );
                      }
                    }
                    assert.isDefined(amount, `args is wrong in ${action.action} testcase`);
                    break;
                  }
                  case "getPricePerFullShareWrite()": {
                    try {
                      const pricePerShare = await contracts[action.contract]
                        .connect(users[action.executer])
                        [action.action]();
                      await pricePerShare.wait();
                    } catch (error) {
                      if (action.expect === "success") {
                        assert.isUndefined(error);
                      } else {
                        expect(error.message).to.equal(
                          `VM Exception while processing transaction: revert ${action.message}`,
                        );
                      }
                    }
                    break;
                  }
                }
              }
              for (let j = 0; j < story.getActions.length; j++) {
                const action = story.getActions[j];
                switch (action.action) {
                  case "pricePerShareWrite()": {
                    const balance = await contracts[action.contract][action.action]();
                    expect(balance).to.be.gt(0);
                    break;
                  }
                }
              }
            }).timeout(100000);
          }
        });
      }
    });
  }
});
