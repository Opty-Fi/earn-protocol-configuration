// SPDX-License-Identifier: MIT

pragma solidity ^0.6.10;
pragma experimental ABIEncoderV2;

import { IOPTYStakingPool } from "../../interfaces/opty/IOPTYStakingPool.sol";
import { SafeERC20, IERC20, SafeMath } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { OPTYStakingRateBalancerStorage } from "./OPTYStakingRateBalancerStorage.sol";
import { OPTYStakingRateBalancerProxy } from "./OPTYStakingRateBalancerProxy.sol";
import { Modifiers } from "../configuration/Modifiers.sol";

contract OPTYStakingRateBalancer is OPTYStakingRateBalancerStorage, Modifiers {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /* solhint-disable no-empty-blocks */
    constructor(address _registry) public Modifiers(_registry) {}

    /* solhint-disable no-empty-blocks */

    /**
     * @dev initialize the different stakingPools
     *
     */
    function initialize(
        address _stakingPool1DLockingTerm,
        address _stakingPool30DLockingTerm,
        address _stakingPool60DLockingTerm,
        address _stakingPool180DLockingTerm
    ) public onlyGovernance {
        stakingPool1DLockingTerm = _stakingPool1DLockingTerm;
        stakingPool30DLockingTerm = _stakingPool30DLockingTerm;
        stakingPool60DLockingTerm = _stakingPool60DLockingTerm;
        stakingPool180DLockingTerm = _stakingPool180DLockingTerm;
        stakingPools[stakingPool1DLockingTerm] = true;
        stakingPools[stakingPool30DLockingTerm] = true;
        stakingPools[stakingPool60DLockingTerm] = true;
        stakingPools[stakingPool180DLockingTerm] = true;
    }

    /**
     * @dev Set OPTYStakingRateBalancerProxy to act as OPTYStakingRateBalancer
     *
     */
    function become(OPTYStakingRateBalancerProxy _optyStakingRateBalancerProxy) public onlyGovernance {
        require(_optyStakingRateBalancerProxy.acceptImplementation() == 0, "!unauthorized");
    }

    modifier onlyStakingPools() {
        require(stakingPools[msg.sender], "!stakingPools");
        _;
    }

    function setStakingPoolMultipliers(address _stakingPool, uint256 _multiplier) public onlyGovernance returns (bool) {
        stakingPoolMultipliers[_stakingPool] = _multiplier;
        return true;
    }

    function setStakingPoolOPTYAllocation(uint256 _stakingPoolOPTYAllocation) public onlyGovernance returns (bool) {
        stakingPoolOPTYAllocation = _stakingPoolOPTYAllocation;
    }

    function updateOptyRates() public onlyStakingPools returns (bool) {
        uint256 _stakingPool1DLockingTermStakedOPTY = stakingPoolToStakedOPTY[stakingPool1DLockingTerm];
        uint256 _stakingPool30DLockingTermStakedOPTY = stakingPoolToStakedOPTY[stakingPool30DLockingTerm];
        uint256 _stakingPool60DLockingTermStakedOPTY = stakingPoolToStakedOPTY[stakingPool60DLockingTerm];
        uint256 _stakingPool180DLockingTermStakedOPTY = stakingPoolToStakedOPTY[stakingPool180DLockingTerm];

        uint256 _weighted1DLockingTermStakedOPTY =
            stakingPoolMultipliers[stakingPool1DLockingTerm].mul(_stakingPool1DLockingTermStakedOPTY);
        uint256 _weighted30DLockingTermStakedOPTY =
            stakingPoolMultipliers[stakingPool30DLockingTerm].mul(_stakingPool30DLockingTermStakedOPTY);
        uint256 _weighted60DLockingTermStakedOPTY =
            stakingPoolMultipliers[stakingPool60DLockingTerm].mul(_stakingPool60DLockingTermStakedOPTY);
        uint256 _weighted180DLockingTermStakedOPTY =
            stakingPoolMultipliers[stakingPool180DLockingTerm].mul(_stakingPool180DLockingTermStakedOPTY);

        uint256 _totalWeightedStakedOPTY =
            _weighted1DLockingTermStakedOPTY
                .add(_weighted30DLockingTermStakedOPTY)
                .add(_weighted60DLockingTermStakedOPTY)
                .add(_weighted180DLockingTermStakedOPTY);
        uint256 _rate1DLock;
        uint256 _rate30DLock;
        uint256 _rate60DLock;
        uint256 _rate180DLock;
        if (_totalWeightedStakedOPTY == uint256(0)) {
            _rate1DLock = uint256(0);
            _rate30DLock = uint256(0);
            _rate60DLock = uint256(0);
            _rate180DLock = uint256(0);
        } else {
            _rate1DLock = stakingPoolOPTYAllocation.mul(_weighted1DLockingTermStakedOPTY).div(_totalWeightedStakedOPTY);
            _rate30DLock = stakingPoolOPTYAllocation.mul(_weighted30DLockingTermStakedOPTY).div(
                _totalWeightedStakedOPTY
            );
            _rate60DLock = stakingPoolOPTYAllocation.mul(_weighted60DLockingTermStakedOPTY).div(
                _totalWeightedStakedOPTY
            );
            _rate180DLock = stakingPoolOPTYAllocation.mul(_weighted180DLockingTermStakedOPTY).div(
                _totalWeightedStakedOPTY
            );
        }

        require(
            IOPTYStakingPool(stakingPool1DLockingTerm).setOptyRatePerSecond(_rate1DLock),
            "updateOptyRates:1Dlockingterm"
        );
        require(
            IOPTYStakingPool(stakingPool30DLockingTerm).setOptyRatePerSecond(_rate30DLock),
            "updateOptyRates:30Dlockingterm"
        );
        require(
            IOPTYStakingPool(stakingPool60DLockingTerm).setOptyRatePerSecond(_rate60DLock),
            "updateOptyRates:160Dlockingterm"
        );
        require(
            IOPTYStakingPool(stakingPool180DLockingTerm).setOptyRatePerSecond(_rate180DLock),
            "updateOptyRates:180Dlockingterm"
        );
        return true;
    }

    function updateStakedOPTY(address _staker, uint256 _amount) public onlyStakingPools returns (bool) {
        stakingPoolToUserStakedOPTY[msg.sender][_staker] = stakingPoolToUserStakedOPTY[msg.sender][_staker].add(
            _amount
        );
        stakingPoolToStakedOPTY[msg.sender] = stakingPoolToStakedOPTY[msg.sender].add(_amount);
        return true;
    }

    function updateUnstakedOPTY(address _staker, uint256 _shares) public onlyStakingPools returns (bool) {
        uint256 _stakerStakedAmount = stakingPoolToUserStakedOPTY[msg.sender][_staker];
        uint256 _amount = _shares.mul(_stakerStakedAmount).div(stakingPoolToStakedOPTY[msg.sender]);
        if (_shares == IERC20(msg.sender).balanceOf(_staker)) {
            stakingPoolToUserStakedOPTY[msg.sender][_staker] = uint256(0);
        } else {
            stakingPoolToUserStakedOPTY[msg.sender][_staker] = stakingPoolToUserStakedOPTY[msg.sender][_staker].sub(
                _amount
            );
        }
        stakingPoolToStakedOPTY[msg.sender] = stakingPoolToStakedOPTY[msg.sender].sub(_amount);
        return true;
    }
}
