// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//  libraries
import { DataTypes } from "./libraries/types/DataTypes.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

//  helper contracts
import { Modifiers } from "./Modifiers.sol";

//  interfaces
import { IStrategyProviderV2 } from "./interfaces/opty/IStrategyProviderV2.sol";
import { Constants } from "./utils/Constants.sol";

/**
 * @title StrategyProvider Contract
 * @author Opty.fi
 * @notice Serves as an oracle service of opty-fi's earn protocol
 * @dev Contracts contains logic for setting and getting the best and default strategy
 * as well as vault reward token strategy
 */
contract StrategyProviderV2 is IStrategyProviderV2, Modifiers {
    using SafeMath for uint256;

    /**
     * @notice Mapping of RiskProfile (eg: RP1, RP2, etc) to tokensHash to the best strategy hash
     */
    mapping(uint256 => mapping(bytes32 => DataTypes.StrategyStep[])) public rpToTokenToBestStrategy;

    /**
     * @notice Mapping of RiskProfile (eg: RP1, RP2, etc) to tokensHash to best default strategy hash
     */
    mapping(uint256 => mapping(bytes32 => DataTypes.StrategyStep[])) public rpToTokenToDefaultStrategy;

    /**
     * @notice Mapping of vaultRewardToken address hash to vault reward token strategy
     */
    mapping(bytes32 => DataTypes.VaultRewardStrategy) public vaultRewardTokenHashToVaultRewardTokenStrategy;

    /* solhint-disable no-empty-blocks */
    constructor(address _registry) public Modifiers(_registry) {}

    /**
     * @inheritdoc IStrategyProviderV2
     */
    function setBestStrategy(
        uint256 _riskProfileCode,
        bytes32 _underlyingTokensHash,
        DataTypes.StrategyStep[] memory _strategySteps
    ) external override onlyStrategyOperator {
        DataTypes.RiskProfile memory _riskProfileStruct = registryContract.getRiskProfile(_riskProfileCode);
        require(_riskProfileStruct.exists, "!Rp_Exists");
        address[] memory _tokens = registryContract.getTokensHashToTokenList(_underlyingTokensHash);
        require(_tokens.length > 0, "!TokenHashExists");
        delete rpToTokenToBestStrategy[_riskProfileCode][_underlyingTokensHash];
        for (uint256 _i = 0; _i < _strategySteps.length; _i++) {
            rpToTokenToBestStrategy[_riskProfileCode][_underlyingTokensHash].push(_strategySteps[_i]);
        }
    }

    /**
     * @inheritdoc IStrategyProviderV2
     */
    function setBestDefaultStrategy(
        uint256 _riskProfileCode,
        bytes32 _underlyingTokensHash,
        DataTypes.StrategyStep[] memory _strategySteps
    ) external override onlyStrategyOperator {
        DataTypes.RiskProfile memory _riskProfileStruct = registryContract.getRiskProfile(_riskProfileCode);
        require(_riskProfileStruct.exists, "!Rp_Exists");
        address[] memory _tokens = registryContract.getTokensHashToTokenList(_underlyingTokensHash);
        require(_tokens.length > 0, "!TokenHashExists");
        delete rpToTokenToDefaultStrategy[_riskProfileCode][_underlyingTokensHash];
        for (uint256 _i = 0; _i < _strategySteps.length; _i++) {
            rpToTokenToDefaultStrategy[_riskProfileCode][_underlyingTokensHash].push(_strategySteps[_i]);
        }
    }

    /**
     * @inheritdoc IStrategyProviderV2
     */
    function setVaultRewardStrategy(
        bytes32 _vaultRewardTokenHash,
        DataTypes.VaultRewardStrategy memory _vaultRewardStrategy
    ) external override onlyStrategyOperator returns (DataTypes.VaultRewardStrategy memory) {
        require(_vaultRewardTokenHash != Constants.ZERO_BYTES32, "!bytes32(0)");
        uint256 _index = registryContract.getTokensHashIndexByHash(_vaultRewardTokenHash);
        require(registryContract.getTokensHashByIndex(_index) == _vaultRewardTokenHash, "!VaultRewardTokenHashExists");
        require(
            (_vaultRewardStrategy.hold.add(_vaultRewardStrategy.convert) == uint256(10000)) ||
                (_vaultRewardStrategy.hold.add(_vaultRewardStrategy.convert) == uint256(0)),
            "!HoldConvertBasisRange"
        );

        vaultRewardTokenHashToVaultRewardTokenStrategy[_vaultRewardTokenHash].hold = _vaultRewardStrategy.hold;
        vaultRewardTokenHashToVaultRewardTokenStrategy[_vaultRewardTokenHash].convert = _vaultRewardStrategy.convert;
        return vaultRewardTokenHashToVaultRewardTokenStrategy[_vaultRewardTokenHash];
    }

    /**
     * @inheritdoc IStrategyProviderV2
     */
    function getVaultRewardTokenHashToVaultRewardTokenStrategy(bytes32 _vaultRewardTokenHash)
        public
        view
        override
        returns (DataTypes.VaultRewardStrategy memory)
    {
        return vaultRewardTokenHashToVaultRewardTokenStrategy[_vaultRewardTokenHash];
    }

    /**
     * @inheritdoc IStrategyProviderV2
     */
    function getRpToTokenToBestStrategy(uint256 _riskProfileCode, bytes32 _underlyingTokensHash)
        external
        view
        override
        returns (DataTypes.StrategyStep[] memory)
    {
        return rpToTokenToBestStrategy[_riskProfileCode][_underlyingTokensHash];
    }

    /**
     * @inheritdoc IStrategyProviderV2
     */
    function getRpToTokenToDefaultStrategy(uint256 _riskProfileCode, bytes32 _underlyingTokensHash)
        external
        view
        override
        returns (DataTypes.StrategyStep[] memory)
    {
        return rpToTokenToDefaultStrategy[_riskProfileCode][_underlyingTokensHash];
    }
}
