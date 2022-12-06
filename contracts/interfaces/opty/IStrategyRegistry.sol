// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//  libraries
import { DataTypes } from "../../libraries/types/DataTypes.sol";

/**
 * @title IStrategyRegistry
 * @author Opty.fi
 * @notice interface to persist vault's strategy definition
 */
interface IStrategyRegistry {
    /**
     * @notice returns the strategy steps metadata for a given strategy
     * @param _strategyHash keccak256 hash of strategy steps metadata
     * @return array of strategy steps
     */
    function getStrategySteps(bytes32 _strategyHash) external view returns (DataTypes.StrategyStep[] memory);

    /**
     * @notice returns the core plan for computing market value of investment in underlying token of the vault
     * @param _strategyHash keccak256 hash of strategy steps metadata
     * @return
     */
    function getOraValueUTPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice
     * @param _strategyHash
     * @return
     */
    function getOraValueLPPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice
     * @param _strategyHash
     * @return
     */
    function getLastStepBalanceLPPlan(address _vault, bytes32 _stategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice
     * @param _strategyHash
     * @return
     */
    function getDepositSomeToStrategyPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice
     * @param _strategyHash
     * @return
     */
    function getDepositAllToStrategyPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice
     * @param _strategyHash
     * @return
     */
    function getWithdrawSomeFromStrategyPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice
     * @param _strategyHash
     * @return
     */
    function getWithdrawAllFromStrategyPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice
     * @param _strategyHash
     * @return
     */
    function getClaimRewardsPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);
}
