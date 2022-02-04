// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//  libraries
import { DataTypes } from "../../libraries/types/DataTypes.sol";

/**
 * @title Interface for StrategyProvider Contract
 * @author Opty.fi
 * @notice Contains functions for setting and getting the best and default strategy
 * as well as vault reward token strategy
 */
interface IStrategyProvider {
    /**
     * @notice Set the best stratetgy for the given riskProfile and tokenHash
     * @param _riskProfileCode Risk profile code (Eg: 1,2, and so on where 0 is reserved for 'no strategy')
     * @param _tokenHash Hash of the underlying token address/addresses
     * @param _strategySteps Strategy steps to be set as best strategy
     */
    function setBestStrategy(
        uint256 _riskProfileCode,
        bytes32 _tokenHash,
        DataTypes.StrategyStep[] memory _strategySteps
    ) external;

    /**
     * @notice Set the best default stratetgy for the given riskProfile and tokenHash
     * @param _riskProfileCode Risk profile code (Eg: 1,2, and so on where 0 is reserved for 'no strategy')
     * @param _tokenHash Hash of the underlying token address/addresses
     * @param _strategySteps Strategy steps to be set as best default strategy
     */
    function setBestDefaultStrategy(
        uint256 _riskProfileCode,
        bytes32 _tokenHash,
        DataTypes.StrategyStep[] memory _strategySteps
    ) external;

    /**
     * @dev Assign strategy in form of vaultRewardStrategy to the vaultRewardTokenHash
     * @param _vaultRewardTokenHash Hash of vault contract and reward token address
     * @param _vaultRewardStrategy Vault reward token's strategy for the specified vaultRewardTokenHash
     * @return Returns a vaultRewardStrategy hash value indicating successful operation
     */
    function setVaultRewardStrategy(
        bytes32 _vaultRewardTokenHash,
        DataTypes.VaultRewardStrategy memory _vaultRewardStrategy
    ) external returns (DataTypes.VaultRewardStrategy memory);

    /**
     * @notice Get the Best strategy corresponding to riskProfile and tokenHash provided
     * @param _riskProfileCode Risk profile code (Eg: 1,2, and so on where 0 is reserved for 'no strategy')
     * @param _tokenHash Hash of the underlying token address/addresses
     * @return Returns the best strategy corresponding to riskProfile and tokenHash provided
     */
    function getRpToTokenToBestStrategy(uint256 _riskProfileCode, bytes32 _tokenHash)
        external
        view
        returns (DataTypes.StrategyStep[] memory);

    /**
     * @notice Get the Best Default strategy corresponding to riskProfile and tokenHash provided
     * @param _riskProfileCode Risk profile code (Eg: 1,2, and so on where 0 is reserved for 'no strategy')
     * @param _tokenHash Hash of the underlying token address/addresses
     * @return Returns the best default strategy corresponding to riskProfile and tokenHash provided
     */
    function getRpToTokenToDefaultStrategy(uint256 _riskProfileCode, bytes32 _tokenHash)
        external
        view
        returns (DataTypes.StrategyStep[] memory);

    /**
     * @notice Get the Vault reward token's strategy corresponding to the tokensHash provided
     * @param _tokensHash Hash of Vault contract and reward token address
     * @return Returns the Vault reward token's strategy corresponding to the tokensHash provided
     */
    function getVaultRewardTokenHashToVaultRewardTokenStrategy(bytes32 _tokensHash)
        external
        view
        returns (DataTypes.VaultRewardStrategy memory);
}
