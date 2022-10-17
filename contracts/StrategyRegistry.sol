// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//RENAME: StrategyRegistry.sol

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
 * @dev Contract to persist vault's strategy definition
 */
contract StrategyRegistry is IStrategyRegistry, Modifiers, StrategyRegistryStorage {
    /* solhint-disable no-empty-blocks */
    constructor(address _registry) public Modifiers(_registry) {}

    /**
     * @inheritdoc IStrategyRegistry
     */
    function getStrategySteps(bytes32 _strategyHash) external view override returns (DataTypes.StrategyStep[] memory) {
        return steps[_strategyHash];
    }

    /**
     * @notice adds new strategy
     * @dev this function can be only called by operator
     * @param _strategyHash keccak256 hash of the strategy steps
     * @param _steps strategy steps containing pool, outputToken, isBorrow
     */
    function addStrategy(bytes32 _strategyHash, DataTypes.StrategyStep[] memory _steps) external onlyOperator {
        _addStrategy(_strategyHash, _steps);
    }

    /**
     * @notice set multiple strategy hash to strategy steps mapping
     * @dev this function can be only called by operator
     * @param _strategyHashes list of keccak256 hash of the strategy steps
     * @param _steps strategy steps containing pool, outputToken, isBorrow
     */
    function addStrategies(bytes32[] memory _strategyHashes, DataTypes.StrategyStep[][] memory _steps)
        external
        onlyOperator
    {
        uint256 _strategyHashLen = _strategyHashes.length;
        require(_strategyHashLen == _steps.length, "!length mismatch");
        for (uint256 _i; _i < _strategyHashLen; _i++) {
            _addStrategy(_strategyHashes[_i], _steps[_i]);
        }
    }

    /**
     * @notice delete a strategy
     * @dev this function can be only called by operator
     * @param _strategyHash keccak256 hash of the strategy steps
     */
    function deleteStrategy(bytes32 _strategyHash) external onlyOperator {
        _deleteStrategy(_strategyHash);
    }

    /**
     * @notice delete multiple strategies
     * @dev this function can be only called by operator
     * @param _strategyHashes list of keccak256 hash of the strategy steps
     */
    function deleteStrategies(bytes32[] memory _strategyHashes) external onlyOperator {
        uint256 _strategyHashLen = _strategyHashes.length;
        for (uint256 _i; _i < _strategyHashLen; _i++) {
            _deleteStrategy(_strategyHashes[_i]);
        }
    }

    /**
     * @dev internal function add new strategy
     * @param _strategyHash keccak256 hash of the strategy steps
     * @param _steps strategy steps containing pool, outputToken, isBorrow
     */
    function _addStrategy(bytes32 _strategyHash, DataTypes.StrategyStep[] memory _steps) internal {
        DataTypes.StrategyStep[] storage steps_ = steps[_strategyHash];
        require(steps_.length == 0, "!isNewStrategy");
        uint256 _stepLength = _steps.length;
        for (uint256 _i; _i < _stepLength; _i++) {
            steps_.push(_steps[_i]);
        }
    }

    /**
     * @dev internal function to delete new strategy
     * @param _strategyHash keccak256 hash of the strategy steps
     */
    function _deleteStrategy(bytes32 _strategyHash) internal {
        delete steps[_strategyHash];
    }
}
