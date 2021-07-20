// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

// helper contracts
import { Modifiers } from "../configuration/Modifiers.sol";
import { OPTYStakingRateBalancerStorage } from "./OPTYStakingRateBalancerStorage.sol";

/**
 * @title OPTYStakingRateBalancerCore
 * @author opty.fi
 * @dev Storage for the OPTYStakingRateBalancer is at this address,
 * while execution is delegated to the `optyStakingRateBalancerImplementation`.
 * OPTYStakingRateBalancer should reference this contract as their controller.
 * It defines a fallback function that delegates all calls to the address
 * returned by the abstract _implementation() internal function.
 */

contract OPTYStakingRateBalancerProxy is OPTYStakingRateBalancerStorage, Modifiers {
    /**
     * @notice Emitted when pendingOPTYStakingRateBalancerImplementation is changed
     */
    event NewPendingImplementation(address oldPendingImplementation, address newPendingImplementation);

    /**
     * @notice Emitted when OPTYStakingRateBalancer implementation is updated
     */
    event NewImplementation(address oldImplementation, address newImplementation);

    /* solhint-disable no-empty-blocks */
    constructor(address _registry) public Modifiers(_registry) {}

    /*** Admin Functions ***/
    function setPendingImplementation(address newPendingImplementation) external onlyOperator {
        address oldPendingImplementation = pendingOPTYStakingRateBalancerImplementation;

        pendingOPTYStakingRateBalancerImplementation = newPendingImplementation;

        emit NewPendingImplementation(oldPendingImplementation, pendingOPTYStakingRateBalancerImplementation);
    }

    /**
     * @notice Accept new implementation of OPTYStakingRateBalancer. msg.sender must be pendingImplementation
     * @dev Governance function for new implementation to accept it's role as implementation
     */
    function acceptImplementation() external returns (uint256) {
        /* Check caller is pendingImplementation and pendingImplementation ≠ address(0) */
        require(
            msg.sender == pendingOPTYStakingRateBalancerImplementation &&
                pendingOPTYStakingRateBalancerImplementation != address(0),
            "!pendingOPTYStakingRateBalancerImplementation"
        );

        /* Save current values for inclusion in log */
        address oldImplementation = optyStakingRateBalancerImplementation;
        address oldPendingImplementation = pendingOPTYStakingRateBalancerImplementation;

        optyStakingRateBalancerImplementation = pendingOPTYStakingRateBalancerImplementation;

        pendingOPTYStakingRateBalancerImplementation = address(0);

        emit NewImplementation(oldImplementation, optyStakingRateBalancerImplementation);
        emit NewPendingImplementation(oldPendingImplementation, pendingOPTYStakingRateBalancerImplementation);

        return uint256(0);
    }

    /* solhint-disable */
    receive() external payable {
        revert();
    }

    /**
     * @dev Delegate execution to an OPTYStakingRateBalancer implementation contract.
     * It returns to the external caller whatever the implementation returns
     * or forwards reverts.
     */
    fallback() external payable {
        /* delegate all other functions to current implementation */
        (bool success, ) = optyStakingRateBalancerImplementation.delegatecall(msg.data);

        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize())

            switch success
                case 0 {
                    revert(free_mem_ptr, returndatasize())
                }
                default {
                    return(free_mem_ptr, returndatasize())
                }
        }
    }
    /* solhint-disable */
}