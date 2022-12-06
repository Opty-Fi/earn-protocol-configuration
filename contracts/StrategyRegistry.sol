// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//  libraries
import { DataTypes } from "./libraries/types/DataTypes.sol";

//  helper contracts
import { Modifiers } from "./Modifiers.sol";
import { StrategyRegistryStorage } from "./StrategyRegistryStorage.sol";

//  interfaces
import { IStrategyRegistry } from "./interfaces/opty/IStrategyRegistry.sol";

/**
 * @title StrategyRegistry Contract
 * @author Opty.fi
 * @dev Contract to persist strategy metadata and there plans
 */
contract StrategyRegistry is IStrategyRegistry, Modifiers, StrategyRegistryStorage {
    /* solhint-disable no-empty-blocks */
    constructor(address _registry) public Modifiers(_registry) {}

    /**
     * @notice adds new strategy
     * @dev this function can be only called by operator
     * @param _strategyHash keccak256 hash of the strategy steps
     * @param _steps strategy steps containing pool, outputToken, isSwap
     */
    function addStrategy(bytes32 _strategyHash, DataTypes.StrategyStep[] memory _steps) external onlyOperator {
        _addStrategySteps(_strategyHash, _steps);
    }

    /**
     * @notice adds new strategy plan
     * @dev this function can be only called by operator
     * @param _vault address of the vault
     * @param _strategyHash keccak256 hash of the strategy steps
     * @param _strategyPlan core plan of the strategy execution
     */
    function addStrategyPlan(
        address _vault,
        bytes32 _strategyHash,
        DataTypes.StrategyPlan memory _strategyPlan
    ) external onlyOperator {
        _addStrategyPlan(_vault, _strategyHash, _strategyPlan);
    }

    /**
     * @notice set multiple strategies
     * @dev all the arguments corresponding to each other in the sequence they are passed.
     *      this function can be only called by operator
     * @param _strategyHashes list of keccak256 hash of the strategy steps
     * @param _steps strategy steps containing pool, outputToken, isSwap
     */
    function addStrategies(bytes32[] memory _strategyHashes, DataTypes.StrategyStep[][] memory _steps)
        external
        onlyOperator
    {
        uint256 _strategyHashLen = _strategyHashes.length;
        uint256 _stepsLen = _steps.length;
        require(_strategyHashLen == _stepsLen, "StrategyRegistry::length mismatch");
        for (uint256 _i; _i < _strategyHashLen; _i++) {
            _addStrategySteps(_strategyHashes[_i], _steps[_i]);
        }
    }

    /**
     * @notice set multiple strategy plans
     * @dev all the arguments corresponding to each other in the sequence they are passed.
     *      this function can be only called by operator
     * @param _vaults list of vault addresses
     * @param _strategyHashes list of keccak256 hash of the strategy steps
     * @param _strategyPlans list of strategy plans for execution
     */
    function addStrategyPlans(
        address[] memory _vaults,
        bytes32[] memory _strategyHashes,
        DataTypes.StrategyPlan[] memory _strategyPlans
    ) external onlyOperator {
        uint256 _vaultLen = _vaults.length;
        uint256 _strategyHashLen = _strategyHashes.length;
        require(
            _vaultLen == _strategyHashLen && _strategyHashLen == _strategyPlans.length,
            "StrategyRegistry::length mismatch"
        );
        for (uint256 _i; _i < _strategyHashLen; _i++) {
            _addStrategyPlan(_vaults[_i], _strategyHashes[_i], _strategyPlans[_i]);
        }
    }

    /**
     * @inheritdoc IStrategyRegistry
     */
    function getStrategySteps(bytes32 _strategyHash) external view override returns (DataTypes.StrategyStep[] memory) {
        return steps[_strategyHash];
    }

    /**
     * @inheritdoc IStrategyRegistry
     */
    function getOraValueUTPlan(address _vault, bytes32 _strategyHash)
        external
        view
        override
        returns (DataTypes.StrategyPlanInput memory)
    {
        return strategyPlans[_vault][_strategyHash].oraValueUTPlan;
    }

    /**
     * @inheritdoc IStrategyRegistry
     */
    function getOraValueLPPlan(address _vault, bytes32 _strategyHash)
        external
        view
        override
        returns (DataTypes.StrategyPlanInput memory)
    {
        return strategyPlans[_vault][_strategyHash].oraValueLPPlan;
    }

    /**
     * @inheritdoc IStrategyRegistry
     */
    function getLastStepBalanceLPPlan(address _vault, bytes32 _stategyHash)
        external
        view
        override
        returns (DataTypes.StrategyPlanInput memory)
    {
        return strategyPlans[_vault][_stategyHash].lastStepBalanceLPPlan;
    }

    /**
     * @inheritdoc IStrategyRegistry
     */
    function getDepositSomeToStrategyPlan(address _vault, bytes32 _strategyHash)
        external
        view
        override
        returns (DataTypes.StrategyPlanInput memory)
    {
        return strategyPlans[_vault][_strategyHash].depositSomeToStrategyPlan;
    }

    /**
     * @inheritdoc IStrategyRegistry
     */
    function getDepositAllToStrategyPlan(address _vault, bytes32 _strategyHash)
        external
        view
        override
        returns (DataTypes.StrategyPlanInput memory)
    {
        return strategyPlans[_vault][_strategyHash].depositAllToStrategyPlan;
    }

    /**
     * @inheritdoc IStrategyRegistry
     */
    function getWithdrawSomeFromStrategyPlan(address _vault, bytes32 _strategyHash)
        external
        view
        override
        returns (DataTypes.StrategyPlanInput memory)
    {
        return strategyPlans[_vault][_strategyHash].withdrawSomeFromStrategyPlan;
    }

    /**
     * @inheritdoc IStrategyRegistry
     */
    function getWithdrawAllFromStrategyPlan(address _vault, bytes32 _strategyHash)
        external
        view
        override
        returns (DataTypes.StrategyPlanInput memory)
    {
        return strategyPlans[_vault][_strategyHash].withdrawAllFromStrategyPlan;
    }

    /**
     * @inheritdoc IStrategyRegistry
     */
    function getClaimRewardsPlan(address _vault, bytes32 _strategyHash)
        external
        view
        override
        returns (DataTypes.StrategyPlanInput memory)
    {
        return strategyPlans[_vault][_strategyHash].claimRewardsPlan;
    }

    /**
     * @dev private function to add new strategy
     * @param _strategyHash keccak256 hash of the strategy steps
     * @param _steps strategy steps containing pool, outputToken, isSwap
     */
    function _addStrategySteps(bytes32 _strategyHash, DataTypes.StrategyStep[] memory _steps) private {
        delete steps[_strategyHash];
        uint256 _stepLength = _steps.length;
        for (uint256 _i; _i < _stepLength; _i++) {
            steps[_strategyHash].push(_steps[_i]);
        }
    }

    /**
     * @dev private function to store core plan for strategy execution
     * @param _strategyHash keccak256 hash of the strategy steps
     * @param _strategyPlan core plan of the strategy execution
     */
    function _addStrategyPlan(
        address _vault,
        bytes32 _strategyHash,
        DataTypes.StrategyPlan memory _strategyPlan
    ) private {
        strategyPlans[_vault][_strategyHash] = _strategyPlan;
    }
}
