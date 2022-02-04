// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//  libraries
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { DataTypes } from "./libraries/types/DataTypes.sol";

//  helper contracts
import { Modifiers } from "./Modifiers.sol";
import { RiskManagerStorage } from "./RiskManagerStorage.sol";
import { RiskManagerProxy } from "./RiskManagerProxy.sol";

//  interfaces
import { IStrategyProvider } from "./interfaces/opty/IStrategyProvider.sol";
import { IRiskManager } from "./interfaces/opty/IRiskManager.sol";
import { Constants } from "./utils/Constants.sol";

/**
 * @title RiskManager Contract
 * @author Opty.fi
 * @dev Contract contains functionality for getting the best invest and vaultRewardToken strategy
 */
contract RiskManager is IRiskManager, RiskManagerStorage, Modifiers {
    using Address for address;

    /* solhint-disable no-empty-blocks */
    constructor(address _registry) public Modifiers(_registry) {}

    /**
     * @dev Set RiskManagerProxy to act as RiskManager
     * @param _riskManagerProxy RiskManagerProxy contract address to act as RiskManager
     */
    function become(RiskManagerProxy _riskManagerProxy) external onlyGovernance {
        require(_riskManagerProxy.acceptImplementation() == 0, "!unauthorized");
    }

    /**
     * @inheritdoc IRiskManager
     */
    function getBestStrategy(uint256 _riskProfileCode, address[] memory _underlyingTokens)
        public
        view
        override
        returns (DataTypes.StrategyStep[] memory)
    {
        bytes32 tokensHash = keccak256(abi.encodePacked(_underlyingTokens));
        DataTypes.StrategyConfiguration memory _strategyConfiguration = registryContract.getStrategyConfiguration();
        return _getBestStrategy(_riskProfileCode, tokensHash, _strategyConfiguration);
    }

    /**
     * @inheritdoc IRiskManager
     */
    function getVaultRewardTokenStrategy(address[] memory _underlyingTokens)
        public
        view
        override
        returns (DataTypes.VaultRewardStrategy memory)
    {
        bytes32 _vaultRewardTokenHash = keccak256(abi.encodePacked(_underlyingTokens));
        return
            IStrategyProvider(registryContract.getStrategyProvider()).getVaultRewardTokenHashToVaultRewardTokenStrategy(
                _vaultRewardTokenHash
            );
    }

    function _getBestStrategy(
        uint256 _riskProfileCode,
        bytes32 _tokensHash,
        DataTypes.StrategyConfiguration memory _strategyConfiguration
    ) internal view returns (DataTypes.StrategyStep[] memory) {
        DataTypes.RiskProfile memory _riskProfileStruct = registryContract.getRiskProfile(_riskProfileCode);
        require(_riskProfileStruct.exists, "!Rp_Exists");

        DataTypes.StrategyStep[] memory _strategySteps =
            IStrategyProvider(_strategyConfiguration.strategyProvider).getRpToTokenToBestStrategy(
                _riskProfileCode,
                _tokensHash
            );
        if (_strategySteps.length == 0 || _isInValidStrategy(_strategySteps, _riskProfileStruct)) {
            _strategySteps = IStrategyProvider(_strategyConfiguration.strategyProvider).getRpToTokenToDefaultStrategy(
                _riskProfileCode,
                _tokensHash
            );
        }

        return _strategySteps;
    }

    function _isInValidStrategy(
        DataTypes.StrategyStep[] memory _strategySteps,
        DataTypes.RiskProfile memory _riskProfileStruct
    ) internal view returns (bool) {
        for (uint256 _i = 0; _i < _strategySteps.length; _i++) {
            DataTypes.LiquidityPool memory _liquidityPool = registryContract.getLiquidityPool(_strategySteps[_i].pool);
            bool _isStrategyInvalid =
                !_liquidityPool.isLiquidityPool ||
                    !(_liquidityPool.rating >= _riskProfileStruct.poolRatingsRange.lowerLimit &&
                        _liquidityPool.rating <= _riskProfileStruct.poolRatingsRange.upperLimit);

            _isStrategyInvalid = !_riskProfileStruct.canBorrow && !_isStrategyInvalid
                ? _strategySteps[_i].isBorrow
                : _isStrategyInvalid;

            if (_isStrategyInvalid) {
                return _isStrategyInvalid;
            }
        }

        return false;
    }
}
