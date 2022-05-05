// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//  libraries
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
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
    using SafeMath for uint256;

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
        returns (DataTypes.Strategy[] memory)
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
        returns (DataTypes.Strategy[] memory)
    {
        address[] memory _tokens = registryContract.getTokensHashToTokenList(_underlyingTokensHash);
        require(_tokens.length > 0, "!TokenHashExists");

        for (uint256 _i; _i < _tokens.length; _i++) {
            require(registryContract.isApprovedToken(_tokens[_i]), "!Token");
        }

        DataTypes.RiskProfile memory _riskProfileStruct = registryContract.getRiskProfile(_riskProfileCode);
        require(_riskProfileStruct.exists, "!Rp_Exists");

        DataTypes.Strategy[] memory _strategies =
            IStrategyProvider(registryContract.getStrategyProvider()).getRpToTokenToBestStrategy(
                _riskProfileCode,
                _underlyingTokensHash
            );
        if (_strategies.length == 0 || _isInValidStrategy(_strategies, _riskProfileStruct)) {
            _strategies = IStrategyProvider(registryContract.getStrategyProvider()).getRpToTokenToDefaultStrategy(
                _riskProfileCode,
                _underlyingTokensHash
            );
        }

        return _strategies;
    }

    function _isInValidStrategy(
        DataTypes.Strategy[] memory _strategies,
        DataTypes.RiskProfile memory _riskProfileStruct
    ) internal view returns (bool) {
        uint256 totalTargetAllocationPercent;
        for (uint256 _i = 0; _i < _strategies.length; _i++) {
            totalTargetAllocationPercent = totalTargetAllocationPercent.add(
                _strategies[_i].targetPercentAllocationInBasis
            );
            if (totalTargetAllocationPercent >= uint256(10000)) {
                return false;
            }
        }
        for (uint256 _i = 0; _i < _strategies.length; _i++) {
            for (uint256 _j = 0; _j < _strategies[_i].strategySteps.length; _j++) {
                DataTypes.LiquidityPool memory _liquidityPool =
                    registryContract.getLiquidityPool(_strategies[_i].strategySteps[_j].pool);
                bool _isStrategyInvalid =
                    !_liquidityPool.isLiquidityPool ||
                        !(_liquidityPool.rating >= _riskProfileStruct.poolRatingsRange.lowerLimit &&
                            _liquidityPool.rating <= _riskProfileStruct.poolRatingsRange.upperLimit);

                _isStrategyInvalid = !_riskProfileStruct.canBorrow && !_isStrategyInvalid
                    ? _strategies[_i].strategySteps[_j].isBorrow
                    : _isStrategyInvalid;

                if (_isStrategyInvalid) {
                    return _isStrategyInvalid;
                }
            }
        }

        return false;
    }
}
