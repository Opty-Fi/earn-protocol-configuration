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
     * @param _vault address of the vault
     * @param _strategyHash keccak256 hash of strategy steps metadata
     * @return
     */
    function getOraValueUTPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice function to return the core plan for computing
     *         market value of investment in underlying token of the vault
     * @param _vault address of the vault
     * @param _strategyHash keccak256 hash of strategy steps metadata
     * @return core plan for computing market value of
     *         investment in underlying token of the vault
     */
    function getOraValueLPPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice function to return core plan for returning the liqudity pool token balance of the
     *        last step of the strategy
     * @param _vault address of the vault
     * @param _strategyHash keccak256 hash of strategy steps metadata
     * @return core plan for returning the liqudity pool token balance of the
     *        last step of the strategy
     */
    function getLastStepBalanceLPPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice function to return core plan for depositing given amount of underlying token amount
     *         to the strategy
     * @param _vault address of the vault
     * @param _strategyHash keccak256 hash of strategy steps metadata
     * @return core plan for depositing given amount of underlying token amount
     *        to the strategy
     */
    function getDepositSomeToStrategyPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice function to return the core plan to withdraw given amount of liquidity pool token
     *         from the strategy
     * @param _vault address of the vault
     * @param _strategyHash keccak256 hash of strategy steps metadata
     * @return core plan to withdraw given amount of liquidity pool token
     *         from the strategy
     */
    function getWithdrawSomeFromStrategyPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice function to return core plan to claim pending rewards token from the strategy
     * @param _vault address of the vault
     * @param _strategyHash keccak256 hash of strategy steps metadata
     * @return core plan to claim pending rewards token from the strategy
     */
    function getClaimRewardsPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);

    /**
     * @notice function to return core plan to harvest rewards held by vault
     * @param _vault address of the vault
     * @param _strategyHash keccak256 hash of strategy steps metadata
     * @return core plan to harvest rewards held by vault
     */
    function getHarvestRewardsPlan(address _vault, bytes32 _strategyHash)
        external
        view
        returns (DataTypes.StrategyPlanInput memory);
}
