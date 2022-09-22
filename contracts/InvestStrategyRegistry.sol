// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//  libraries
import { DataTypes } from "./libraries/types/DataTypes.sol";

//  helper contracts
import { Modifiers } from "./Modifiers.sol";
import { InvestStrategyRegistryStorage } from "./InvestStrategyRegistryStorage.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";

//  interfaces
import { IInvestStrategyRegistry } from "./interfaces/opty/IInvestStrategyRegistry.sol";

/**
 * @title InvestStrategyRegistry Contract
 * @author Opty.fi
 * @dev Contract to persist vault's step invest strategy definition
 */
contract InvestStrategyRegistry is IInvestStrategyRegistry, Modifiers, InvestStrategyRegistryStorage {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    /**
     * @notice Emitted when hash strategy is set
     * @param tokensHash Hash of token/list of tokens for which strategy is set
     * @param strategyHash Hash of strategy steps which is set for the above tokensHash
     * @param caller Address of user who has called the respective function to trigger this event
     */
    event LogSetVaultInvestStrategy(bytes32 indexed tokensHash, bytes32 indexed strategyHash, address indexed caller);

    event AddStrategy(address _vault, bytes32 _strategyHash);

    event RemoveStrategy(address _vault, bytes32 _strategyHash);

    /* solhint-disable no-empty-blocks */
    constructor(address _registry) public Modifiers(_registry) {}

    /**
     * @inheritdoc IInvestStrategyRegistry
     */
    function addStrategy(
        address _vault, 
        bytes32 _strategyHash, 
        DataTypes.StrategyStep[] memory _steps, 
        DataTypes.StrategyConfiguration memory _configuration, 
        uint256 _withdrawalBuffer
    ) external override onlyStrategyOperator {
        _addStrategy(_vault, _strategyHash, _steps, _configuration, _withdrawalBuffer);
    }

    /**
     * @inheritdoc IInvestStrategyRegistry
     */
    function removeStrategy(
        address _vault,
        bytes32 _strategyHash
    ) external override onlyStrategyOperator {
        _removeStrategy(_vault, _strategyHash);
    }

    function _addStrategy(
        address _vault, 
        bytes32 _strategyHash, 
        DataTypes.StrategyStep[] memory _steps, 
        DataTypes.StrategyConfiguration memory _configuration, 
        uint256 _withdrawalBuffer
    ) internal {
        DataTypes.Portfolio storage p = portfolios[_vault];
        
        require(
            !p.strategies.contains(_strategyHash),
            "InvestStrategyRegistry: strategy already set"
        );

        p.strategies.add(_strategyHash);

        DataTypes.StrategyStep[] storage steps_ = p.steps[_strategyHash];
        uint256 stepLength = _steps.length;

        for(uint i; i < stepLength; i++) {
            steps_.push(_steps[i]);
        }

        
        p.configurations[_strategyHash] = _configuration;
        p.withdrawalBuffers[_strategyHash] = _withdrawalBuffer;
        
        emit AddStrategy(_vault, _strategyHash);
    }

    function _removeStrategy(
        address _vault,
        bytes32 _strategyHash
    ) internal {
        DataTypes.Portfolio storage p = portfolios[_vault];

        require(
            p.balances[_strategyHash] == 0,
            "InvestStrategyRegistry: cannot remove strategy with non-zero balance"
        );
        require(
            p.strategies.contains(_strategyHash),
            "InvestStrategyRegistry: strategy does not exist"
        );

        p.strategies.remove(_strategyHash);
        delete p.balances[_strategyHash];
        delete p.steps[_strategyHash];
        delete p.configurations[_strategyHash];
        delete p.withdrawalBuffers[_strategyHash];

        emit RemoveStrategy(_vault, _strategyHash);
    }


}