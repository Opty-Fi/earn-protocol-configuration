// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//  libraries
import { DataTypes } from "../../libraries/types/DataTypes.sol";

/**
 * @title IInvestStrategyRegistry
 * @author Opty.fi
 * @notice Contains functionality to setting all the strategies for all tokens
 */
interface IInvestStrategyRegistry {
   
   /**
    * @notice adds a strategy to a vaults portfolio
    * @param _vault address of vault
    * @param _strategyHash hash of strategy
    * @param _steps strategy steps
    * @param _configuration strategy configuration
    * @param _withdrawalBuffer buffer for withdrawals
    */ 
   function addStrategy(
        address _vault, 
        bytes32 _strategyHash, 
        DataTypes.StrategyStep[] memory _steps, 
        DataTypes.StrategyConfiguration memory _configuration, 
        uint256 _withdrawalBuffer
   ) external;

   /**
    * @notice removes a strategy from a vaults portfolio
    * @param _vault addres of vault
    * @param _strategyHash hash of strategy
    */
   function removeStrategy(
        address _vault,
        bytes32 _strategyHash
   ) external;
}
