// SPDX-License-Identifier: MIT

pragma solidity ^0.6.10;

/**
 * @title The interface for OPTY minter
 * @author opty.fi
 * @notice The OPTY minter mints the governance token earned by loyal opty.fi users
 */

interface IOPTYMinter {
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function setOperatorUnlockClaimOPTYTimestamp(uint256 _operatorUnlockClaimOPTYTimestamp) external returns (bool);

    /**
     * @dev Maps staking vault to a boolean variable that indicates wether the staking pool is enabled`or not
     *
     */
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function setStakingVault(address _stakingPool, bool _enable) external returns (bool);

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function claimAndStake(address _stakingPool) external;

    /**
     * @notice Claim all the OPTY accrued by holder in all markets
     * @param _holder The address to claim OPTY for
     */
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function claimOpty(address _holder) external returns (uint256);

    /**
     * @notice Claim all the OPTY accrued by holder in the specified markets
     * @param _holder The address to claim OPTY for
     * @param _optyVaults The list of vaults to claim OPTY in
     */
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function claimOpty(address _holder, address[] memory _optyVaults) external returns (uint256);

    /**
     * @notice Claim all opty accrued by the holders
     * @param _holders The addresses to claim OPTY for
     * @param _optyVaults The list of vaults to claim OPTY in
     */
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function claimOpty(address[] memory _holders, address[] memory _optyVaults) external returns (uint256);

    /**
     * @notice Calculate additional accrued OPTY for a contributor since last accrual
     * @param _user The address to calculate contributor rewards for
     */
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function updateUserRewards(address _optyVault, address _user) external;

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function updateUserStateInVault(address _optyVault, address _user) external;

    /**
     * @notice Set the OPTY rate for a specific pool
     * @return The amount of OPTY which was NOT transferred to the user
     */
    function updateOptyVaultRatePerSecondAndVaultToken(address _optyVault) external returns (bool);

    /**
     * @notice Accrue OPTY to the market by updating the supply index
     * @param _optyVault The market whose index to update
     */
    function updateOptyVaultIndex(address _optyVault) external returns (uint224);

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function mintOpty(address _user, uint256 _amount) external returns (uint256);

    /**
     * @notice Set the OPTY rate for a specific pool
     * @return The amount of OPTY which was NOT transferred to the user
     */
    function setOptyVaultRate(address _optyVault, uint256 _rate) external returns (bool);

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function addOptyVault(address _optyVault) external returns (bool);

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function setOptyVault(address _optyVault, bool _enable) external returns (bool);

    /**
     * @notice Claim all the opty accrued by holder in all markets
     * @param _holder The address to claim OPTY for
     */
    function claimableOpty(address _holder) external view returns (uint256);

    /**
     * @notice Claim all the opty accrued by holder in the specified markets
     * @param _holder The address to claim OPTY for
     * @param _optyVaults The list of vaults to claim OPTY in
     */
    function claimableOpty(address _holder, address[] memory _optyVaults) external view returns (uint256);

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function currentOptyVaultIndex(address _optyVault) external view returns (uint256);

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function getOptyAddress() external view returns (address);
}
