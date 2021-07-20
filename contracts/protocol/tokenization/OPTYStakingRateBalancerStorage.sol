// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

/**
 * @title OPTY staking rate balancer state that can change
 * @author opty.fi
 * @dev The storage contract for staking rate balancer
 */

contract OPTYStakingRateBalancerStorage {
    /**
     * @notice Active brains of Staking Rate Balancer
     */
    address public optyStakingRateBalancerImplementation;

    /**
     * @notice Pending brains of Staking Rate Balancer
     */
    address public pendingOPTYStakingRateBalancerImplementation;

    /**
     * @notice This variable stores the 1 day locking term's staking vault address
     */
    address public stakingVault1DLockingTerm;

    /**
     * @notice This variable stores the 30 days locking term's staking vault address
     */
    address public stakingVault30DLockingTerm;

    /**
     * @notice This variable stores the 60 days locking term's staking vault address
     */
    address public stakingVault60DLockingTerm;

    /**
     * @notice This variable stores the 180 days locking term's staking vault address
     */
    address public stakingVault180DLockingTerm;

    /**
     * @notice This variable stores active staking vaults
     */
    mapping(address => bool) public stakingVaults;

    /**
     * @notice This variable stores $OPTY staked in staking vault
     */
    mapping(address => uint256) public stakingVaultToStakedOPTY;

    /**
     * @notice This variable stores $OPTY staked in staking vault per user
     */
    mapping(address => mapping(address => uint256)) public stakingVaultToUserStakedOPTY;

    /**
     * @notice The coefficient of $OPTY for staking vault
     *         with different period
     */
    mapping(address => uint256) public stakingVaultMultipliers;

    /**
     * @notice Total amount of $OPTY allocated to staking vaults
     */
    uint256 public stakingVaultOPTYAllocation;
}