// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import { RiskManagerStorage } from "../../RiskManagerStorage.sol";
import { RiskManagerProxy } from "../../RiskManagerProxy.sol";
import { Modifiers } from "../../Modifiers.sol";
import { TestStorageV2 } from "./TestStorageV2.sol";

contract TestRiskManagerNewImplementation is RiskManagerStorage, TestStorageV2, Modifiers {
    /* solhint-disable no-empty-blocks */
    constructor(address _registry) public Modifiers(_registry) {}

    /**
     * @dev Set TestRiskManagerNewImplementation to act as RiskManager
     * @param _riskManagerProxy RiskManagerProxy contract address to act as RiskManager
     */
    function become(RiskManagerProxy _riskManagerProxy) external onlyGovernance {
        require(_riskManagerProxy.acceptImplementation() == 0, "!unauthorized");
    }

    function isNewContract() external pure returns (bool) {
        return isNewVariable;
    }
}
