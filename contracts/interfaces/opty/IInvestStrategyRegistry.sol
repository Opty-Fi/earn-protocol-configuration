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
    * @notice fetches the strategy steps for a given strategy
    * @param _strategyHash strategyHash of strategy 
    * @return StrategyStep array of steps
    */
   function getStrategySteps(
        bytes32 _strategyHash
   ) external view returns (DataTypes.StrategyStep[] memory);
   
   /**
    * @notice returns the withdrawal buffer for a given strategy of a target vault
    * @param _vault address of the vault
    * @param _strategyHash the hash of the strategy to check
    * @return uint256 the buffer 
    */
   function getStrategyWithdrawalBuffer(
       address _vault, 
       bytes32 _strategyHash
   ) external view returns (uint256);
}
