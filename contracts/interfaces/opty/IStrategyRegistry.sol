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
     * @notice fetches the strategy steps for a given strategy
     * @param _strategyHash strategyHash of strategy
     * @return StrategyStep array of steps
     */
    function getStrategySteps(bytes32 _strategyHash) external view returns (DataTypes.StrategyStep[] memory);
}
