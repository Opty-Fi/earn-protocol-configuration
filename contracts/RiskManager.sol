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
import { IStrategyRegistry } from "./interfaces/opty/IStrategyRegistry.sol";
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
    function getBestStrategy(uint256 _riskProfileCode, bytes32 _underlyingTokensHash)
        public
        view
        override
        returns (DataTypes.StrategyStep[] memory)
    {
        return _getBestStrategy(_riskProfileCode, _underlyingTokensHash);
    }

    /**
     * @inheritdoc IRiskManager
     */
    function getVaultRewardTokenStrategy(bytes32 _underlyingTokensHash)
        public
        view
        override
        returns (DataTypes.VaultRewardStrategy memory)
    {
        return
            IStrategyProvider(registryContract.getStrategyProvider()).getVaultRewardTokenHashToVaultRewardTokenStrategy(
                _underlyingTokensHash
            );
    }

    function _getBestStrategy(uint256 _riskProfileCode, bytes32 _underlyingTokensHash)
        internal
        view
        returns (DataTypes.StrategyStep[] memory)
    {
        address[] memory _tokens = registryContract.getTokensHashToTokenList(_underlyingTokensHash);
        require(_tokens.length > 0, "!TokenHashExists");

        for (uint256 _i; _i < _tokens.length; _i++) {
            require(registryContract.isApprovedToken(_tokens[_i]), "!Token");
        }

        DataTypes.RiskProfile memory _riskProfileStruct = registryContract.getRiskProfile(_riskProfileCode);
        require(_riskProfileStruct.exists, "!Rp_Exists");

        DataTypes.StrategyStep[] memory _strategySteps =
            IStrategyProvider(registryContract.getStrategyProvider()).getRpToTokenToBestStrategy(
                _riskProfileCode,
                _underlyingTokensHash
            );
        if (_strategySteps.length == 0 || _isInValidStrategy(_strategySteps, _riskProfileStruct)) {
            _strategySteps = IStrategyProvider(registryContract.getStrategyProvider()).getRpToTokenToDefaultStrategy(
                _riskProfileCode,
                _underlyingTokensHash
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

    function isValidStrategy(bytes32 _strategyHash, uint256 _riskProfileCode) external override {
        require(
            !_isInValidStrategy(
                IStrategyRegistry(registryContract.getStrategyRegistry()).getStrategySteps(_strategyHash),
                registryContract.getRiskProfile(_riskProfileCode)
            ),
            "Strategy invalid"
        );
    }
}
