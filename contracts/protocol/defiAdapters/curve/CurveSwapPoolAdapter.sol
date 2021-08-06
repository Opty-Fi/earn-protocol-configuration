// solhint-disable no-unused-vars
// SPDX-License-Identifier:MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//  libraries
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { DataTypes } from "../../../libraries/types/DataTypes.sol";

//  helper contracts
import { Modifiers } from "../../configuration/Modifiers.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

//  interfaces
import { IAdapter } from "../../../interfaces/opty/defiAdapters/IAdapter.sol";
import { IAdapterHarvestReward } from "../../../interfaces/opty/defiAdapters/IAdapterHarvestReward.sol";
import { IAdapterStaking } from "../../../interfaces/opty/defiAdapters/IAdapterStaking.sol";
import { IAdapterInvestLimit } from "../../../interfaces/opty/defiAdapters/IAdapterInvestLimit.sol";
import { IAdapterStakingCurve } from "../../../interfaces/opty/defiAdapters/IAdapterStakingCurve.sol";
import { ICurveDeposit } from "../../../interfaces/curve/ICurveDeposit.sol";
import { ICurveSwap } from "../../../interfaces/curve/ICurveSwap.sol";
import { ICurveGauge } from "../../../interfaces/curve/ICurveGauge.sol";
import { ICurveAddressProvider } from "../../../interfaces/curve/ICurveAddressProvider.sol";
import { ICurveRegistry } from "../../../interfaces/curve/ICurveRegistry.sol";
import { IHarvestCodeProvider } from "../../../interfaces/opty/IHarvestCodeProvider.sol";
import { ITokenMinter } from "../../../interfaces/curve/ITokenMinter.sol";

/**
 * @title Adapter for Curve Swap pools
 * @author Opty.fi
 * @dev Abstraction layer to Curve's swap pools
 *      Note 1 : In this adapter, a liquidity pool is actually swap pool
 *      Note 2 : In this adapter, a swap pool is defined as a single-sided liquidity pool
 *      Note 3 : In this adapter, lp token can be redemeed into more than one underlying token
 */
contract CurveSwapPoolAdapter is
    IAdapter,
    IAdapterHarvestReward,
    IAdapterStaking,
    IAdapterInvestLimit,
    IAdapterStakingCurve,
    Modifiers
{
    using SafeMath for uint256;

    /** @notice  Curve Registry Address Provider */
    address public constant ADDRESS_PROVIDER = address(0x0000000022D53366457F9d5E68Ec105046FC4383);

    /** @notice HBTC token contract address */
    address public constant HBTC = address(0x0316EB71485b0Ab14103307bf65a021042c6d380);

    /** @notice max deposit's default value in percentage */
    uint256 public maxDepositProtocolPct; // basis points

    /** @notice Maps liquidityPool to absolute max deposit value in underlying */
    mapping(address => uint256) public maxDepositAmount;

    /** @notice  Maps liquidityPool to max deposit value in percentage */
    mapping(address => uint256) public maxDepositPoolPct; // basis points

    /** @notice max deposit value datatypes */
    DataTypes.MaxExposure public maxDepositProtocolMode;

    /**
     * @dev mapp coins and tokens to curve deposit pool
     */
    constructor(address _registry) public Modifiers(_registry) {
        setMaxDepositProtocolPct(uint256(10000)); // 100% (basis points)
        setMaxDepositProtocolMode(DataTypes.MaxExposure.Pct);
    }

    /**
     * @inheritdoc IAdapterInvestLimit
     */
    function setMaxDepositPoolPct(address _liquidityPool, uint256 _maxDepositPoolPct)
        external
        override
        onlyRiskOperator
    {
        maxDepositPoolPct[_liquidityPool] = _maxDepositPoolPct;
        emit LogMaxDepositPoolPct(address(this), maxDepositPoolPct[_liquidityPool], msg.sender);
    }

    /**
     * @inheritdoc IAdapterInvestLimit
     */
    function setMaxDepositAmount(
        address _liquidityPool,
        address,
        uint256 _maxDepositAmount
    ) external override onlyRiskOperator {
        // Note : We are using 18 as decimals for USD and BTC
        maxDepositAmount[_liquidityPool] = _maxDepositAmount;
        emit LogMaxDepositAmount(address(this), maxDepositAmount[_liquidityPool], msg.sender);
    }

    /**
     * @inheritdoc IAdapterInvestLimit
     */
    function setMaxDepositProtocolMode(DataTypes.MaxExposure _mode) public override onlyRiskOperator {
        maxDepositProtocolMode = _mode;
        emit LogMaxDepositProtocolMode(address(this), maxDepositProtocolMode, msg.sender);
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function setRewardToken(address) public override onlyOperator {
        revert("!empty");
    }

    /**
     * @inheritdoc IAdapterInvestLimit
     */
    function setMaxDepositProtocolPct(uint256 _maxDepositProtocolPct) public override onlyRiskOperator {
        maxDepositProtocolPct = _maxDepositProtocolPct;
        emit LogMaxDepositProtocolPct(address(this), maxDepositProtocolPct, msg.sender);
    }

    /**
     * @inheritdoc IAdapterStakingCurve
     */
    function getAllAmountInTokenStakeWrite(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool
    ) external override returns (uint256) {
        uint256 _liquidityPoolTokenAmount = getLiquidityPoolTokenBalanceStake(_vault, _liquidityPool);
        uint256 _b;
        if (_liquidityPoolTokenAmount > 0) {
            _b = ICurveDeposit(_liquidityPool).calc_withdraw_one_coin(
                _liquidityPoolTokenAmount,
                _getTokenIndex(_liquidityPool, _underlyingToken)
            );
        }
        _b = _b.add(
            IHarvestCodeProvider(registryContract.getHarvestCodeProvider()).rewardBalanceInUnderlyingTokens(
                getRewardToken(_liquidityPool),
                _underlyingToken,
                _getUnclaimedRewardTokenAmountWrite(_vault, _liquidityPool)
            )
        );
        return _b;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getPoolValue(address _liquidityPool, address) public view override returns (uint256) {
        uint256 _virtualPrice = ICurveSwap(_liquidityPool).get_virtual_price();
        uint256 _totalSupply = ERC20(getLiquidityPoolToken(address(0), _liquidityPool)).totalSupply();
        // the pool value will be in USD for US dollar stablecoin pools
        // the pool value will be in BTC for BTC pools
        return (_virtualPrice.mul(_totalSupply)).div(10**18);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getDepositAllCodes(
        address payable _vault,
        address[] memory _underlyingTokens,
        address _liquidityPool
    ) public view override returns (bytes[] memory _codes) {
        uint256 _amount = ERC20(_underlyingTokens[0]).balanceOf(_vault);
        _codes = _getDepositCode(_underlyingTokens[0], _liquidityPool, _amount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getWithdrawAllCodes(
        address payable _vault,
        address[] memory _underlyingTokens,
        address _liquidityPool
    ) public view override returns (bytes[] memory _codes) {
        uint256 _amount = getLiquidityPoolTokenBalance(_vault, _underlyingTokens[0], _liquidityPool);
        return getWithdrawSomeCodes(_vault, _underlyingTokens, _liquidityPool, _amount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getUnderlyingTokens(address _liquidityPool, address)
        public
        view
        override
        returns (address[] memory _underlyingTokens)
    {
        address _curveRegistry = _getCurveRegistry();
        address[8] memory _underlyingCoins = _getUnderlyingTokens(_liquidityPool, _curveRegistry);
        uint256 _nCoins = _getNCoins(_liquidityPool, _curveRegistry);
        _underlyingTokens = new address[](_nCoins);
        for (uint256 _i = 0; _i < _nCoins; _i++) {
            _underlyingTokens[_i] = _underlyingCoins[_i];
        }
    }

    /**
     * @inheritdoc IAdapter
     * @dev Reverting '!empty' message as there is no related functionality for this in CurveSwap pool
     */
    function calculateAmountInLPToken(
        address,
        address,
        uint256
    ) public view override returns (uint256) {
        revert("!empty");
    }

    /**
     * @inheritdoc IAdapter
     */
    function calculateRedeemableLPTokenAmount(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _redeemAmount
    ) public view override returns (uint256 _amount) {
        uint256 _liquidityPoolTokenBalance = getLiquidityPoolTokenBalance(_vault, _underlyingToken, _liquidityPool);
        uint256 _balanceInToken = getAllAmountInToken(_vault, _underlyingToken, _liquidityPool);
        // can have unintentional rounding errors
        _amount = (_liquidityPoolTokenBalance.mul(_redeemAmount)).div(_balanceInToken).add(1);
    }

    /**
     * @inheritdoc IAdapter
     */
    function isRedeemableAmountSufficient(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _redeemAmount
    ) public view override returns (bool) {
        uint256 _balanceInToken = getAllAmountInToken(_vault, _underlyingToken, _liquidityPool);
        return _balanceInToken >= _redeemAmount;
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getClaimRewardTokenCode(address payable, address _liquidityPool)
        public
        view
        override
        returns (bytes[] memory _codes)
    {
        address _curveRegistry = _getCurveRegistry();
        address _liquidityGauge = _getLiquidityGauge(_liquidityPool, _curveRegistry);
        if (_liquidityGauge != address(0)) {
            _codes = new bytes[](1);
            _codes[0] = abi.encode(
                getMinter(_liquidityGauge),
                abi.encodeWithSignature("mint(address)", _liquidityGauge)
            );
        }
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getHarvestAllCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool
    ) public view override returns (bytes[] memory _codes) {
        uint256 _rewardTokenAmount = ERC20(getRewardToken(_liquidityPool)).balanceOf(_vault);
        return getHarvestSomeCodes(_vault, _underlyingToken, _liquidityPool, _rewardTokenAmount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function canStake(address _liquidityPool) public view override returns (bool) {
        address _curveRegistry = _getCurveRegistry();
        if (_getLiquidityGauge(_liquidityPool, _curveRegistry) != address(0)) {
            return true;
        }
        return false;
    }

    /**
     * @inheritdoc IAdapterStaking
     */
    function getStakeAllCodes(
        address payable _vault,
        address[] memory _underlyingTokens,
        address _liquidityPool
    ) public view override returns (bytes[] memory _codes) {
        uint256 _stakeAmount = getLiquidityPoolTokenBalance(_vault, _underlyingTokens[0], _liquidityPool);
        return getStakeSomeCodes(_liquidityPool, _stakeAmount);
    }

    /**
     * @inheritdoc IAdapterStaking
     */
    function getUnstakeAllCodes(address payable _vault, address _liquidityPool)
        public
        view
        override
        returns (bytes[] memory _codes)
    {
        uint256 _unstakeAmount = getLiquidityPoolTokenBalanceStake(_vault, _liquidityPool);
        return getUnstakeSomeCodes(_liquidityPool, _unstakeAmount);
    }

    /**
     * @inheritdoc IAdapterStaking
     */
    function calculateRedeemableLPTokenAmountStake(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _redeemAmount
    ) public view override returns (uint256 _amount) {
        uint256 _stakedLiquidityPoolTokenBalance = getLiquidityPoolTokenBalanceStake(_vault, _liquidityPool);
        uint256 _balanceInTokenStaked = getAllAmountInTokenStake(_vault, _underlyingToken, _liquidityPool);
        // can have unintentional rounding errors
        _amount = (_stakedLiquidityPoolTokenBalance.mul(_redeemAmount)).div(_balanceInTokenStaked).add(1);
    }

    /**
     * @inheritdoc IAdapterStaking
     */
    function isRedeemableAmountSufficientStake(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _redeemAmount
    ) public view override returns (bool) {
        uint256 _balanceInTokenStaked = getAllAmountInTokenStake(_vault, _underlyingToken, _liquidityPool);
        return _balanceInTokenStaked >= _redeemAmount;
    }

    /**
     * @inheritdoc IAdapterStaking
     */
    function getUnstakeAndWithdrawAllCodes(
        address payable _vault,
        address[] memory _underlyingTokens,
        address _liquidityPool
    ) public view override returns (bytes[] memory _codes) {
        uint256 _redeemAmount = getLiquidityPoolTokenBalanceStake(_vault, _liquidityPool);
        return getUnstakeAndWithdrawSomeCodes(_vault, _underlyingTokens, _liquidityPool, _redeemAmount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getDepositSomeCodes(
        address payable,
        address[] memory _underlyingTokens,
        address _liquidityPool,
        uint256[] memory _amounts
    ) public view override returns (bytes[] memory _codes) {
        _codes = _getDepositCode(_underlyingTokens[0], _liquidityPool, _amounts[0]);
    }

    /**
     * @inheritdoc IAdapter
     * @dev Note : swap pools of compound,usdt,pax,y,susd and busd
     *             does not have remove_liquidity_one_coin function
     */
    function getWithdrawSomeCodes(
        address payable,
        address[] memory _underlyingTokens,
        address _liquidityPool,
        uint256 _amount
    ) public view override returns (bytes[] memory _codes) {
        if (_amount > 0) {
            address _liquidityPoolToken = getLiquidityPoolToken(address(0), _liquidityPool);
            _codes = new bytes[](3);
            _codes[0] = abi.encode(
                _liquidityPoolToken,
                abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, uint256(0))
            );
            _codes[1] = abi.encode(
                _liquidityPoolToken,
                abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, _amount)
            );
            uint256 _numOfTokens = _underlyingTokens.length;
            if (_numOfTokens == 1) {
                _codes[2] = abi.encode(
                    _liquidityPool,
                    // solhint-disable-next-line max-line-length
                    abi.encodeWithSignature(
                        "remove_liquidity_one_coin(uint256,int128,uint256)",
                        _amount,
                        _getTokenIndex(_liquidityPool, _underlyingTokens[0]),
                        uint256(0)
                    )
                );
            } else if (_numOfTokens == uint256(2)) {
                uint256[2] memory _minAmountOut = [uint256(0), uint256(0)];
                _codes[2] = abi.encode(
                    _liquidityPool,
                    abi.encodeWithSignature("remove_liquidity(uint256,uint256[2])", _amount, _minAmountOut)
                );
            } else if (_numOfTokens == uint256(3)) {
                uint256[3] memory _minAmountOut = [uint256(0), uint256(0), uint256(0)];
                _codes[2] = abi.encode(
                    _liquidityPool,
                    abi.encodeWithSignature("remove_liquidity(uint256,uint256[3])", _amount, _minAmountOut)
                );
            } else if (_numOfTokens == uint256(4)) {
                uint256[4] memory _minAmountOut = [uint256(0), uint256(0), uint256(0), uint256(0)];
                _codes[2] = abi.encode(
                    _liquidityPool,
                    abi.encodeWithSignature("remove_liquidity(uint256,uint256[4])", _amount, _minAmountOut)
                );
            }
        }
    }

    /**
     * @inheritdoc IAdapter
     */
    function getLiquidityPoolToken(address, address _liquidityPool) public view override returns (address) {
        return ICurveRegistry(_getCurveRegistry()).get_lp_token(_liquidityPool);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getAllAmountInToken(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool
    ) public view override returns (uint256) {
        uint256 _liquidityPoolTokenAmount = getLiquidityPoolTokenBalance(_vault, _underlyingToken, _liquidityPool);
        return getSomeAmountInToken(_underlyingToken, _liquidityPool, _liquidityPoolTokenAmount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getLiquidityPoolTokenBalance(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool
    ) public view override returns (uint256) {
        return ERC20(getLiquidityPoolToken(_underlyingToken, _liquidityPool)).balanceOf(_vault);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getSomeAmountInToken(
        address _underlyingToken,
        address _liquidityPool,
        uint256 _liquidityPoolTokenAmount
    ) public view override returns (uint256) {
        if (_liquidityPoolTokenAmount > 0) {
            return
                ICurveDeposit(_liquidityPool).calc_withdraw_one_coin(
                    _liquidityPoolTokenAmount,
                    _getTokenIndex(_liquidityPool, _underlyingToken)
                );
        }
        return 0;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getRewardToken(address _liquidityPool) public view override returns (address) {
        address _curveRegistry = _getCurveRegistry();
        address _liquidityGauge = _getLiquidityGauge(_liquidityPool, _curveRegistry);
        if (_liquidityGauge != address(0)) {
            return ITokenMinter(getMinter(_liquidityGauge)).token();
        }
        return address(0);
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getUnclaimedRewardTokenAmount(
        address payable,
        address _liquidityPool,
        address
    ) public view override returns (uint256) {
        /* solhint-disable no-empty-blocks */
        if (_getLiquidityGauge(_liquidityPool, _getCurveRegistry()) != address(0)) {
            // TODO : get the amount of unclaimed CRV tokens
        }
        /* solhint-disable no-empty-blocks */
        return uint256(0);
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getHarvestSomeCodes(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool,
        uint256 _rewardTokenAmount
    ) public view override returns (bytes[] memory _codes) {
        return
            IHarvestCodeProvider(registryContract.getHarvestCodeProvider()).getHarvestCodes(
                _vault,
                getRewardToken(_liquidityPool),
                _underlyingToken,
                _rewardTokenAmount
            );
    }

    /* solhint-disable no-empty-blocks */

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getAddLiquidityCodes(address payable, address) public view override returns (bytes[] memory) {}

    /* solhint-enable no-empty-blocks */

    /**
     * @inheritdoc IAdapterStaking
     */
    function getStakeSomeCodes(address _liquidityPool, uint256 _stakeAmount)
        public
        view
        override
        returns (bytes[] memory _codes)
    {
        if (_stakeAmount > 0) {
            address _curveRegistry = _getCurveRegistry();
            address _liquidityGauge = _getLiquidityGauge(_liquidityPool, _curveRegistry);
            address _liquidityPoolToken = getLiquidityPoolToken(address(0), _liquidityPool);
            _codes = new bytes[](3);
            _codes[0] = abi.encode(
                _liquidityPoolToken,
                abi.encodeWithSignature("approve(address,uint256)", _liquidityGauge, uint256(0))
            );
            _codes[1] = abi.encode(
                _liquidityPoolToken,
                abi.encodeWithSignature("approve(address,uint256)", _liquidityGauge, _stakeAmount)
            );
            _codes[2] = abi.encode(_liquidityGauge, abi.encodeWithSignature("deposit(uint256)", _stakeAmount));
        }
    }

    /**
     * @inheritdoc IAdapterStaking
     */
    function getUnstakeSomeCodes(address _liquidityPool, uint256 _unstakeAmount)
        public
        view
        override
        returns (bytes[] memory _codes)
    {
        if (_unstakeAmount > 0) {
            address _curveRegistry = _getCurveRegistry();
            address _liquidityGauge = _getLiquidityGauge(_liquidityPool, _curveRegistry);
            _codes = new bytes[](1);
            _codes[0] = abi.encode(_liquidityGauge, abi.encodeWithSignature("withdraw(uint256)", _unstakeAmount));
        }
    }

    /**
     * @inheritdoc IAdapterStaking
     */
    function getAllAmountInTokenStake(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool
    ) public view override returns (uint256) {
        uint256 _liquidityPoolTokenAmount = getLiquidityPoolTokenBalanceStake(_vault, _liquidityPool);
        uint256 _b = 0;
        if (_liquidityPoolTokenAmount > 0) {
            _b = ICurveDeposit(_liquidityPool).calc_withdraw_one_coin(
                _liquidityPoolTokenAmount,
                _getTokenIndex(_liquidityPool, _underlyingToken)
            );
        }
        _b = _b.add(
            IHarvestCodeProvider(registryContract.getHarvestCodeProvider()).rewardBalanceInUnderlyingTokens(
                getRewardToken(_liquidityPool),
                _underlyingToken,
                getUnclaimedRewardTokenAmount(_vault, _liquidityPool, _underlyingToken)
            )
        );
        return _b;
    }

    /**
     * @inheritdoc IAdapterStaking
     */
    function getLiquidityPoolTokenBalanceStake(address payable _vault, address _liquidityPool)
        public
        view
        override
        returns (uint256)
    {
        return ICurveGauge(_getLiquidityGauge(_liquidityPool, _getCurveRegistry())).balanceOf(_vault);
    }

    /**
     * @inheritdoc IAdapterStaking
     */
    function getUnstakeAndWithdrawSomeCodes(
        address payable _vault,
        address[] memory _underlyingTokens,
        address _liquidityPool,
        uint256 _redeemAmount
    ) public view override returns (bytes[] memory _codes) {
        if (_redeemAmount > 0) {
            _codes = new bytes[](4);
            _codes[0] = getUnstakeSomeCodes(_liquidityPool, _redeemAmount)[0];
            bytes[] memory _withdrawCodes =
                getWithdrawSomeCodes(_vault, _underlyingTokens, _liquidityPool, _redeemAmount);
            _codes[1] = _withdrawCodes[0];
            _codes[2] = _withdrawCodes[1];
            _codes[3] = _withdrawCodes[2];
        }
    }

    /**
     * @notice Get the Curve Minter's address
     */
    function getMinter(address _gauge) public view returns (address) {
        return ICurveGauge(_gauge).minter();
    }

    /**
     * @dev This function composes the configuration required to construct fuction calls
     * @param _underlyingToken address of the underlying asset
     * @param _swapPool swap pool address
     * @param _amount amount in underlying token
     * @return _nCoins number of underlying tokens in swap pool
     * @return _underlyingTokens underlying tokens in a swap pool
     * @return _amounts value in an underlying token for each underlying token
     * @return _codeLength number of function call required for deposit
     */
    function _getDepositCodeConfig(
        address _underlyingToken,
        address _swapPool,
        uint256 _amount
    )
        internal
        view
        returns (
            uint256 _nCoins,
            address[8] memory _underlyingTokens,
            uint256[] memory _amounts,
            uint256 _codeLength
        )
    {
        address _curveRegistry = _getCurveRegistry();
        _nCoins = _getNCoins(_swapPool, _curveRegistry);
        _underlyingTokens = _getUnderlyingTokens(_swapPool, _curveRegistry);
        _amounts = new uint256[](_nCoins);
        _codeLength = 1;
        for (uint256 _i = 0; _i < _nCoins; _i++) {
            if (_underlyingTokens[_i] == _underlyingToken) {
                _amounts[_i] = _getDepositAmount(_swapPool, _underlyingToken, _amount);
                if (_amounts[_i] > 0) {
                    if (_underlyingTokens[_i] == HBTC) {
                        _codeLength++;
                    } else {
                        _codeLength += 2;
                    }
                }
            }
        }
    }

    /**
     * @dev This functions returns the token index for a underlying token
     * @param _underlyingToken address of the underlying asset
     * @param _swapPool swap pool address
     * @return _tokenIndex index of coin in swap pool
     */
    function _getTokenIndex(address _swapPool, address _underlyingToken) internal view returns (int128 _tokenIndex) {
        address[8] memory _underlyingTokens = _getUnderlyingTokens(_swapPool, _getCurveRegistry());
        for (uint256 _i = 0; _i < _underlyingTokens.length; _i++) {
            if (_underlyingTokens[_i] == _underlyingToken) {
                _tokenIndex = int128(_i);
                break;
            }
        }
    }

    /**
     * @dev Returns the amount of accrued reward tokens for a specific OptyFi's vault
     * @param _vault Address of the OptyFi's vault contract
     * @param _swapPool Address of the swap pool contract
     * @return Returns the amount of accrued reward tokens
     */
    function _getUnclaimedRewardTokenAmountWrite(address payable _vault, address _swapPool) internal returns (uint256) {
        if (_getLiquidityGauge(_swapPool, _getCurveRegistry()) != address(0)) {
            return ICurveGauge(_swapPool).claimable_tokens(_vault);
        }
        return uint256(0);
    }

    /**
     * @dev This functions composes the function calls to deposit asset into deposit pool
     * @param _underlyingToken address of the underlying asset
     * @param _swapPool swap pool address
     * @param _amount the amount in underlying token
     * @return _codes bytes array of function calls to be executed from vault
     */
    function _getDepositCode(
        address _underlyingToken,
        address _swapPool,
        uint256 _amount
    ) internal view returns (bytes[] memory _codes) {
        (uint256 _nCoins, address[8] memory _underlyingTokens, uint256[] memory _amounts, uint256 _codeLength) =
            _getDepositCodeConfig(_underlyingToken, _swapPool, _amount);
        if (_codeLength > 1) {
            _codes = new bytes[](_codeLength);
            uint256 _j = 0;
            for (uint256 i = 0; i < _nCoins; i++) {
                if (_amounts[i] > 0) {
                    if (_underlyingTokens[i] == HBTC) {
                        _codes[_j++] = abi.encode(
                            _underlyingTokens[i],
                            abi.encodeWithSignature("approve(address,uint256)", _swapPool, _amounts[i])
                        );
                    } else {
                        _codes[_j++] = abi.encode(
                            _underlyingTokens[i],
                            abi.encodeWithSignature("approve(address,uint256)", _swapPool, uint256(0))
                        );
                        _codes[_j++] = abi.encode(
                            _underlyingTokens[i],
                            abi.encodeWithSignature("approve(address,uint256)", _swapPool, _amounts[i])
                        );
                    }
                }
            }
            if (_nCoins == uint256(2)) {
                uint256[2] memory _depositAmounts = [_amounts[0], _amounts[1]];
                _codes[_j] = abi.encode(
                    _swapPool,
                    abi.encodeWithSignature("add_liquidity(uint256[2],uint256)", _depositAmounts, uint256(0))
                );
            } else if (_nCoins == uint256(3)) {
                uint256[3] memory _depositAmounts = [_amounts[0], _amounts[1], _amounts[2]];
                _codes[_j] = abi.encode(
                    _swapPool,
                    abi.encodeWithSignature("add_liquidity(uint256[3],uint256)", _depositAmounts, uint256(0))
                );
            } else if (_nCoins == uint256(4)) {
                uint256[4] memory _depositAmounts = [_amounts[0], _amounts[1], _amounts[2], _amounts[3]];
                _codes[_j] = abi.encode(
                    _swapPool,
                    abi.encodeWithSignature("add_liquidity(uint256[4],uint256)", _depositAmounts, uint256(0))
                );
            }
        }
    }

    /**
     * @dev Get the underlying tokens within a swap pool.
     *      Note: For pools using lending, these are the
     *            wrapped coin addresses
     * @param _swapPool the swap pool address
     * @param _curveRegistry the address of the Curve registry
     * @return list of coin addresses
     */
    function _getUnderlyingTokens(address _swapPool, address _curveRegistry) internal view returns (address[8] memory) {
        return ICurveRegistry(_curveRegistry).get_coins(_swapPool);
    }

    /**
     * @dev Get a liquidity gauge address associated with a swap pool
     * @param _swapPool the swap pool address
     * @param _curveRegistry the Curve registry's address
     * @return gauge address
     */
    function _getLiquidityGauge(address _swapPool, address _curveRegistry) internal view returns (address) {
        (address[10] memory _liquidityGauges, ) = ICurveRegistry(_curveRegistry).get_gauges(_swapPool);
        return _liquidityGauges[0];
    }

    /**
     * @dev Get the address of the main registry contract
     * @return Address of the main registry contract
     */
    function _getCurveRegistry() internal view returns (address) {
        return ICurveAddressProvider(ADDRESS_PROVIDER).get_registry();
    }

    /**
     * @dev Get number of underlying tokens in a liquidity pool
     * @param _swapPool swap pool address associated with liquidity pool
     * @param _curveRegistry address of the main registry contract
     * @return  Number of underlying tokens
     */
    function _getNCoins(address _swapPool, address _curveRegistry) internal view returns (uint256) {
        return ICurveRegistry(_curveRegistry).get_n_coins(_swapPool)[0];
    }

    /**
     * @dev Get the final value of amount in underlying token to be deposited
     * @param _swapPool swap pool address
     * @param _underlyingToken underlying token address
     * @param _amount amount in underlying token
     * @return amount in underlying token to be deposited affected by investment limitation
     */
    function _getDepositAmount(
        address _swapPool,
        address _underlyingToken,
        uint256 _amount
    ) internal view returns (uint256) {
        return
            maxDepositProtocolMode == DataTypes.MaxExposure.Pct
                ? _getMaxDepositAmountPct(_swapPool, _underlyingToken, _amount)
                : _getMaxDepositAmount(_swapPool, _underlyingToken, _amount);
    }

    /**
     * @dev Gets the maximum amount in underlying token limited by percentage
     * @param _swapPool swap pool address
     * @param _underlyingToken underlying token address
     * @param _amount amount in underlying token
     * @return  amount in underlying token to be deposited affected by
     *          investment limit in percentage
     */
    function _getMaxDepositAmountPct(
        address _swapPool,
        address _underlyingToken,
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 _poolValue = getPoolValue(_swapPool, _underlyingToken);
        uint256 _poolPct = maxDepositPoolPct[_swapPool];
        uint256 _decimals = ERC20(_underlyingToken).decimals();
        uint256 _actualAmount = _amount.mul(10**(uint256(18).sub(_decimals)));
        uint256 _limit =
            _poolPct == 0 ? _poolValue.mul(maxDepositProtocolPct).div(10000) : _poolValue.mul(_poolPct).div(10000);
        return _actualAmount > _limit ? _limit.div(10**(uint256(18).sub(_decimals))) : _amount;
    }

    /**
     * @dev Gets the maximum amount in underlying token affected by investment
     *      limit set for swap pool in amount
     * @param _swapPool swap pool address
     * @param _underlyingToken underlying token address
     * @param _amount amount in underlying token
     * @return amount in underlying token to be deposited affected by
     *         investment limit set for swap pool in amount
     */
    function _getMaxDepositAmount(
        address _swapPool,
        address _underlyingToken,
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 _decimals = ERC20(_underlyingToken).decimals();
        uint256 _maxAmount = maxDepositAmount[_swapPool].div(10**(uint256(18).sub(_decimals)));
        return _amount > _maxAmount ? _maxAmount : _amount;
    }
}
