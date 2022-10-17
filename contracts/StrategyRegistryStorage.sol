// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import { DataTypes } from "./libraries/types/DataTypes.sol";

contract StrategyRegistryStorage {
    /** @dev strategy => strategy metadata */
    mapping(bytes32 => DataTypes.StrategyStep[]) internal steps;
}
