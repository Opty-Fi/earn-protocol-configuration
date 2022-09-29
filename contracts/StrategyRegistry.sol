// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//RENAME: StrategyRegistry.sol

//  libraries
import { DataTypes } from "./libraries/types/DataTypes.sol";

//  helper contracts
import { Modifiers } from "./Modifiers.sol";
import { StrategyRegistryStorage } from "./StrategyRegistryStorage.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";

//  interfaces
import { IStrategyRegistry } from "./interfaces/opty/IStrategyRegistry.sol";

/**
 * @title StrategyRegistry Contract
 * @author Opty.fi
 * @dev Contract to persist vault's step invest strategy definition
 */
contract StrategyRegistry is IStrategyRegistry, Modifiers, StrategyRegistryStorage {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    /**
     * @notice Emitted when hash strategy is set
     * @param tokensHash Hash of token/list of tokens for which strategy is set
     * @param strategyHash Hash of strategy steps which is set for the above tokensHash
     * @param caller Address of user who has called the respective function to trigger this event
     */
    event LogSetVaultInvestStrategy(bytes32 indexed tokensHash, bytes32 indexed strategyHash, address indexed caller);

    /* solhint-disable no-empty-blocks */
    constructor(address _registry) public Modifiers(_registry) {}

    /**
     * @inheritdoc IStrategyRegistry
     */
    function getStrategySteps(
        bytes32 _strategyHash
    ) external view override returns (DataTypes.StrategyStep[] memory) {
        return steps[_strategyHash]; 
    }

    function addStrategySteps(
        bytes32 _strategyHash, 
        DataTypes.StrategyStep[] memory _steps
    ) external onlyStrategyOperator {
        DataTypes.StrategyStep[] storage steps_ = steps[_strategyHash];
        uint256 stepLength = _steps.length;

        for(uint i; i < stepLength; i++) {
            steps_.push(_steps[i]);
        }
    }

    function deleteStrategySteps(
        bytes32 _strategyHash
    ) external onlyStrategyOperator {
        delete steps[_strategyHash];
    }
}