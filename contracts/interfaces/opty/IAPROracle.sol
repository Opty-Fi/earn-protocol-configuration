// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

/**
 * @title Interface for APROracle Contract
 * @author Opty.fi inspired on yearn.finance APROracle contract
 * @notice Interface to getting the APRs from aave and compund protocols
 * @dev Interface for faciliating the best APR calculation among aave and compound
 */
interface IAPROracle {
    /**
     * @notice Get the APR for the token from Compound protocol
     * @param token Token address for which you want to get APR
     * @return APR corresponding to the token provided
     */
    function getCompoundAPR(address token) external view returns (uint256);

    /**
     * @notice Get the APR for the token from AaveV1 protocol
     * @param token Token address for which you want to get APR
     * @return APR corresponding to the token provided
     */
    function getAaveV1APR(address token) external view returns (address, uint256);

    /**
     * @notice Get the APR for the token from AaveV2 protocol
     * @param token Token address for which you want to get APR
     * @return APR corresponding to the token provided
     */
    function getAaveV2APR(address token) external view returns (address, uint256);

    /**
     * @notice Get the best strategy for the token among compound and aave
     * @param tokensHash Hash of token address/addresses
     * @return Best strategy hash corresponding to the tokens hash provided
     */
    function getBestAPR(bytes32 tokensHash) external view returns (bytes32);
}
