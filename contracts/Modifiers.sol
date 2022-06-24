// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

//  libraries
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { DataTypes } from "./libraries/types/DataTypes.sol";

//  interfaces
import { IRegistry } from "./interfaces/opty/IRegistry.sol";
import { IModifiers } from "./interfaces/opty/IModifiers.sol";

/**
 * @title Modifiers Contract
 * @author Opty.fi
 * @notice Contract used to keep all the modifiers at one place
 * @dev Contract is used throughout the contracts expect registry contract
 */
abstract contract Modifiers is IModifiers {
    /**
     * @notice Registry contract instance address
     */
    IRegistry public registryContract;

    using Address for address;

    constructor(address _registry) internal {
        registryContract = IRegistry(_registry);
    }

    /**
     * @inheritdoc IModifiers
     */
    function setRegistry(address _registry) external override onlyOperator {
        require(_registry.isContract(), "!isContract");
        registryContract = IRegistry(_registry);
    }

    /**
     * @notice Modifier to check if the address is zero address or not
     */
    modifier onlyValidAddress() {
        _onlyValidAddress();
        _;
    }

    /**
     * @notice Modifier to check caller is governance or not
     */
    modifier onlyGovernance() {
        _onlyGovernance();
        _;
    }

    /**
     * @notice Modifier to check caller is financeOperator or not
     */
    modifier onlyFinanceOperator() {
        _onlyFinanceOperator();
        _;
    }

    /**
     * @notice Modifier to check caller is riskOperator or not
     */
    modifier onlyRiskOperator() {
        _onlyRiskOperator();
        _;
    }

    /**
     * @notice Modifier to check caller is operator or not
     */
    modifier onlyStrategyOperator() {
        _onlyStrategyOperator();
        _;
    }

    /**
     * @notice Modifier to check caller is operator or not
     */
    modifier onlyOperator() {
        _onlyOperator();
        _;
    }

    /**
     * @notice Modifier to check caller is optyDistributor or not
     */
    modifier onlyOPTYDistributor() {
        _onlyOPTYDistributor();
        _;
    }

    /**
     * @notice Modifier to check caller is registry or not
     */
    modifier onlyRegistry() {
        _onlyRegistry();
        _;
    }

    function _onlyValidAddress() private view {
        require(msg.sender != address(0), "caller is zero address");
    }

    function _onlyGovernance() private view {
        require(msg.sender == registryContract.getGovernance(), "caller is not having governance");
    }

    function _onlyFinanceOperator() private view {
        require(msg.sender == registryContract.getFinanceOperator(), "caller is not the financeOperator");
    }

    function _onlyRiskOperator() private view {
        require(msg.sender == registryContract.getRiskOperator(), "caller is not the riskOperator");
    }

    function _onlyStrategyOperator() private view {
        require(msg.sender == registryContract.getStrategyOperator(), "caller is not the strategyOperator");
    }

    function _onlyOperator() private view {
        require(msg.sender == registryContract.getOperator(), "caller is not the operator");
    }

    function _onlyOPTYDistributor() private view {
        require(msg.sender == registryContract.getOPTYDistributor(), "!optyDistributor");
    }

    function _onlyRegistry() private view {
        require(msg.sender == address(registryContract), "!Registry Contract");
    }
}
