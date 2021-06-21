// solhint-disable no-unused-vars
// SPDX-License-Identifier:MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//  libraries
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

//  helper contracts
import { Modifiers } from "../../configuration/Modifiers.sol";
import { HarvestCodeProvider } from "../../configuration/HarvestCodeProvider.sol";

//  interfaces
import { IAdapter } from "../../../interfaces/opty/defiAdapters/IAdapter.sol";
import { IAdapterProtocolConfig } from "../../../interfaces/opty/defiAdapters/IAdapterProtocolConfig.sol";
import { IAdapterHarvestReward } from "../../../interfaces/opty/defiAdapters/IAdapterHarvestReward.sol";
import { IAdapterStaking } from "../../../interfaces/opty/defiAdapters/IAdapterStaking.sol";
import { IAdapterCurveInvestLimit } from "../../../interfaces/opty/defiAdapters/IAdapterCurveInvestLimit.sol";
import { ICurveDeposit } from "../../../interfaces/curve/ICurveDeposit.sol";
import { ICurveSwap } from "../../../interfaces/curve/ICurveSwap.sol";
import { ICurveGauge } from "../../../interfaces/curve/ICurveGauge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Adapter for Curve Swap pools
 * @author Opty.fi
 * @dev Abstraction layer to Curve's swap pools
 */
contract CurveSwapAdapter is
    IAdapter,
    IAdapterProtocolConfig,
    IAdapterHarvestReward,
    IAdapterStaking,
    IAdapterCurveInvestLimit,
    Modifiers
{
    using SafeMath for uint256;

    /** @notice Mapping  of swapPool to the underlyingTokens */
    mapping(address => address[]) public swapPoolToUnderlyingTokens;
    /** @notice Mapping  of swapPool to the LiquidityPoolToken */
    mapping(address => address) public swapPoolToLiquidityPoolToken;
    /** @notice Mapping  of swapPool to the Gauge contract address */
    mapping(address => address) public swapPoolToGauges;
    /** @notice Mapping  of swapPool to status of removing liquidity pool for 1 coin */
    mapping(address => bool) public noRemoveLiquidityOneCoin;
    /** @notice  Maps liquidityPool to max deposit value in percentage */
    mapping(address => uint256) public maxDepositPoolPct; // basis points
    /** @notice  Maps liquidityPool to list of 2 max deposit values in number */
    mapping(address => uint256[2]) public maxDeposit2Amount;
    /** @notice  Maps liquidityPool to list of 3 max deposit values in number */
    mapping(address => uint256[3]) public maxDeposit3Amount;
    /** @notice  Maps liquidityPool to list of 4 max deposit values in number */
    mapping(address => uint256[4]) public maxDeposit4Amount;

    // underlying token
    address public constant DAI = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address public constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant USDT = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address public constant PAX = address(0x8E870D67F660D95d5be530380D0eC0bd388289E1);
    address public constant SUSD = address(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51);
    address public constant REN_BTC = address(0xEB4C2781e4ebA804CE9a9803C67d0893436bB27D);
    address public constant WBTC = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address public constant SBTC = address(0xfE18be6b3Bd88A2D2A7f928d00292E7a9963CfC6);
    address public constant HBTC = address(0x0316EB71485b0Ab14103307bf65a021042c6d380);
    address public constant GUSD = address(0x056Fd409E1d7A124BD7017459dFEa2F387b6d5Cd);
    address public constant HUSD = address(0xdF574c24545E5FfEcb9a659c229253D4111d87e1);
    address public constant USDK = address(0x1c48f86ae57291F7686349F12601910BD8D470bb);
    address public constant USDN = address(0x1c48f86ae57291F7686349F12601910BD8D470bb);
    address public constant LINKUSD = address(0x0E2EC54fC0B509F445631Bf4b91AB8168230C752);
    address public constant MUSD = address(0xe2f2a5C287993345a840Db3B0845fbC70f5935a5);
    address public constant RSV = address(0x196f4727526eA7FB1e17b2071B3d8eAA38486988);
    address public constant TBTC = address(0x8dAEBADE922dF735c38C80C7eBD708Af50815fAa);
    address public constant CDAI = address(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    address public constant CUSDC = address(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
    address public constant YCDAI = address(0x99d1Fa417f94dcD62BfE781a1213c092a47041Bc);
    address public constant YCUSDC = address(0x9777d7E2b60bB01759D0E2f8be2095df444cb07E);
    address public constant YCUSDT = address(0x1bE5d71F2dA660BFdee8012dDc58D024448A0A59);
    address public constant YDAI = address(0xC2cB1040220768554cf699b0d863A3cd4324ce32);
    address public constant YUSDC = address(0x26EA744E5B887E5205727f55dFBE8685e3b21951);
    address public constant YUSDT = address(0xE6354ed5bC4b393a5Aad09f21c46E101e692d447);
    address public constant YTUSD = address(0x73a052500105205d34Daf004eAb301916DA8190f);
    address public constant YBUSD = address(0x04bC0Ab673d88aE9dbC9DA2380cB6B79C4BCa9aE);
    address public constant DUSD = address(0x5BC25f649fc4e26069dDF4cF4010F9f706c23831);

    // swap pool
    address public constant COMPOUND_SWAP_POOL = address(0xA2B47E3D5c44877cca798226B7B8118F9BFb7A56);
    address public constant USDT_SWAP_POOL = address(0x52EA46506B9CC5Ef470C5bf89f17Dc28bB35D85C);
    address public constant PAX_SWAP_POOL = address(0x06364f10B501e868329afBc005b3492902d6C763);
    address public constant Y_SWAP_POOL = address(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    address public constant BUSD_SWAP_POOL = address(0x79a8C46DeA5aDa233ABaFFD40F3A0A2B1e5A4F27);
    address public constant SUSD_SWAP_POOL = address(0xA5407eAE9Ba41422680e2e00537571bcC53efBfD);
    address public constant REN_SWAP_POOL = address(0x93054188d876f558f4a66B2EF1d97d16eDf0895B);
    address public constant SBTC_SWAP_POOL = address(0x7fC77b5c7614E1533320Ea6DDc2Eb61fa00A9714);
    address public constant HBTC_SWAP_POOL = address(0x4CA9b3063Ec5866A4B82E437059D2C43d1be596F);
    address public constant THREE_SWAP_POOL = address(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    address public constant GUSD_SWAP_POOL = address(0x4f062658EaAF2C1ccf8C8e36D6824CDf41167956);
    address public constant HUSD_SWAP_POOL = address(0x3eF6A01A0f81D6046290f3e2A8c5b843e738E604);
    address public constant USDK_SWAP_POOL = address(0x3E01dD8a5E1fb3481F0F589056b428Fc308AF0Fb);
    address public constant USDN_SWAP_POOL = address(0x0f9cb53Ebe405d49A0bbdBD291A65Ff571bC83e1);
    address public constant LINKUSD_SWAP_POOL = address(0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171);
    address public constant MUSD_SWAP_POOL = address(0x8474DdbE98F5aA3179B3B3F5942D724aFcdec9f6);
    address public constant RSV_SWAP_POOL = address(0xC18cC39da8b11dA8c3541C598eE022258F9744da);
    address public constant TBTC_SWAP_POOL = address(0xC25099792E9349C7DD09759744ea681C7de2cb66);
    address public constant DUSD_SWAP_POOL = address(0x8038C01A0390a8c547446a0b2c18fc9aEFEcc10c);

    // liquidity pool tokens
    address public constant CDAI_CUSDC = address(0x845838DF265Dcd2c412A1Dc9e959c7d08537f8a2);
    address public constant CDAI_CUSD_CUSDT = address(0x9fC689CCaDa600B6DF723D9E47D84d76664a1F23);
    address public constant Y_PAX_CRV = address(0xD905e2eaeBe188fc92179b6350807D8bd91Db0D8);
    address public constant YDAI_YUSDC_YUSDT_YTUSD = address(0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8);
    address public constant YDAI_YUSDC_YUSDT_YBUSD = address(0x3B3Ac5386837Dc563660FB6a0937DFAa5924333B);
    address public constant CRV_PLAIN_3_AND_SUSD = address(0xC25a3A3b969415c80451098fa907EC722572917F);
    address public constant CRV_REN_WBTC = address(0x49849C98ae39Fff122806C06791Fa73784FB3675);
    address public constant CRV_REN_BTC_WBTC_SBTC = address(0x075b1bb99792c9E1041bA13afEf80C91a1e70fB3);
    address public constant HCRV = address(0xb19059ebb43466C323583928285a49f558E572Fd);
    address public constant THREE_CRV = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    address public constant GUSD_THREE_CRV = address(0xD2967f45c4f384DEEa880F807Be904762a3DeA07);
    address public constant HUSD_THREE_CRV = address(0x5B5CFE992AdAC0C9D48E05854B2d91C73a003858);
    address public constant USDK_THREE_CRV = address(0x97E2768e8E73511cA874545DC5Ff8067eB19B787);
    address public constant USDN_THREE_CRV = address(0x4f3E8F405CF5aFC05D68142F3783bDfE13811522);
    address public constant LINKUSD_THREE_CRV = address(0x6D65b498cb23deAba52db31c93Da9BFFb340FB8F);
    address public constant MUSD_THREE_CRV = address(0x1AEf73d49Dedc4b1778d0706583995958Dc862e6);
    address public constant RSV_THREE_CRV = address(0xC2Ee6b0334C261ED60C72f6054450b61B8f18E35);
    address public constant TBTC_SBTC_CRV = address(0x64eda51d3Ad40D56b9dFc5554E06F94e1Dd786Fd);
    address public constant DUSD_THREE_CRV = address(0x3a664Ab939FD8482048609f652f9a0B0677337B9);

    /** @notice HarvestCodeProvider contract instance */
    HarvestCodeProvider public harvestCodeProviderContract;

    /** @notice CurveSwap Pools's reward token address */
    address public rewardToken;

    /** @notice max deposit's default value in percentage */
    uint256 public maxDepositPoolPctDefault; // basis points

    /** @notice list of max deposit's default values in number */
    uint256[4] public maxDepositAmountDefault;

    /**
     * @dev mapp coins and tokens to curve deposit pool
     */
    constructor(address _registry, address _harvestCodeProvider) public Modifiers(_registry) {
        setHarvestCodeProvider(_harvestCodeProvider);
        // reward token
        setRewardToken(address(0xD533a949740bb3306d119CC777fa900bA034cd52));

        // swap pool
        address[] memory _compoundUnderTokens = new address[](2);
        _compoundUnderTokens[0] = CDAI;
        _compoundUnderTokens[1] = CUSDC;
        setSwapPoolToLiquidityPoolToken(COMPOUND_SWAP_POOL, CDAI_CUSDC);
        setSwapPoolToUnderlyingTokens(COMPOUND_SWAP_POOL, _compoundUnderTokens);
        toggleNoRemoveLiquidityOneCoin(COMPOUND_SWAP_POOL);

        address[] memory _usdtUnderTokens = new address[](3);
        _usdtUnderTokens[0] = CDAI;
        _usdtUnderTokens[1] = CUSDC;
        _usdtUnderTokens[2] = USDT;
        setSwapPoolToLiquidityPoolToken(USDT_SWAP_POOL, CDAI_CUSD_CUSDT);
        setSwapPoolToUnderlyingTokens(USDT_SWAP_POOL, _usdtUnderTokens);
        toggleNoRemoveLiquidityOneCoin(USDT_SWAP_POOL);

        address[] memory _paxUnderTokens = new address[](4);
        _paxUnderTokens[0] = YCDAI;
        _paxUnderTokens[1] = YCUSDC;
        _paxUnderTokens[2] = YCUSDT;
        _paxUnderTokens[3] = PAX;
        setSwapPoolToLiquidityPoolToken(PAX_SWAP_POOL, Y_PAX_CRV);
        setSwapPoolToUnderlyingTokens(PAX_SWAP_POOL, _paxUnderTokens);
        toggleNoRemoveLiquidityOneCoin(PAX_SWAP_POOL);

        address[] memory _yUnderTokens = new address[](4);
        _yUnderTokens[0] = YDAI;
        _yUnderTokens[1] = YUSDC;
        _yUnderTokens[2] = YUSDT;
        _yUnderTokens[3] = YTUSD;
        setSwapPoolToLiquidityPoolToken(Y_SWAP_POOL, YDAI_YUSDC_YUSDT_YTUSD);
        setSwapPoolToUnderlyingTokens(Y_SWAP_POOL, _yUnderTokens);
        toggleNoRemoveLiquidityOneCoin(Y_SWAP_POOL);

        address[] memory _busdUnderTokens = new address[](4);
        _busdUnderTokens[0] = YDAI;
        _busdUnderTokens[1] = YUSDC;
        _busdUnderTokens[2] = YUSDT;
        _busdUnderTokens[3] = YBUSD;
        setSwapPoolToLiquidityPoolToken(BUSD_SWAP_POOL, YDAI_YUSDC_YUSDT_YBUSD);
        setSwapPoolToUnderlyingTokens(BUSD_SWAP_POOL, _compoundUnderTokens);
        toggleNoRemoveLiquidityOneCoin(BUSD_SWAP_POOL);

        address[] memory _susdUnderTokens = new address[](4);
        _susdUnderTokens[0] = DAI;
        _susdUnderTokens[1] = USDC;
        _susdUnderTokens[2] = USDT;
        _susdUnderTokens[3] = SUSD;
        setSwapPoolToLiquidityPoolToken(SUSD_SWAP_POOL, CRV_PLAIN_3_AND_SUSD);
        setSwapPoolToUnderlyingTokens(SUSD_SWAP_POOL, _susdUnderTokens);
        toggleNoRemoveLiquidityOneCoin(SUSD_SWAP_POOL);

        address[] memory _crvrenBTCwBTCUnderTokens = new address[](2);
        _crvrenBTCwBTCUnderTokens[0] = REN_BTC;
        _crvrenBTCwBTCUnderTokens[1] = WBTC;
        setSwapPoolToLiquidityPoolToken(REN_SWAP_POOL, CRV_REN_WBTC);
        setSwapPoolToUnderlyingTokens(REN_SWAP_POOL, _crvrenBTCwBTCUnderTokens);

        address[] memory _crvrenBTCwBTCsBTCUnderTokens = new address[](3);
        _crvrenBTCwBTCsBTCUnderTokens[0] = REN_BTC;
        _crvrenBTCwBTCsBTCUnderTokens[1] = WBTC;
        _crvrenBTCwBTCsBTCUnderTokens[2] = SBTC;
        setSwapPoolToLiquidityPoolToken(SBTC_SWAP_POOL, CRV_REN_BTC_WBTC_SBTC);
        setSwapPoolToUnderlyingTokens(SBTC_SWAP_POOL, _crvrenBTCwBTCsBTCUnderTokens);

        address[] memory _crvhBTCwBTCUnderTokens = new address[](2);
        _crvhBTCwBTCUnderTokens[0] = HBTC;
        _crvhBTCwBTCUnderTokens[1] = WBTC;
        setSwapPoolToLiquidityPoolToken(HBTC_SWAP_POOL, HCRV);
        setSwapPoolToUnderlyingTokens(HBTC_SWAP_POOL, _crvhBTCwBTCUnderTokens);

        address[] memory _crvDAIUSDCUSDTUnderTokens = new address[](3);
        _crvDAIUSDCUSDTUnderTokens[0] = DAI;
        _crvDAIUSDCUSDTUnderTokens[1] = USDC;
        _crvDAIUSDCUSDTUnderTokens[2] = USDT;
        setSwapPoolToLiquidityPoolToken(THREE_SWAP_POOL, THREE_CRV);
        setSwapPoolToUnderlyingTokens(THREE_SWAP_POOL, _crvDAIUSDCUSDTUnderTokens);

        address[] memory _gusdUnderlyingTokens = new address[](2);
        _gusdUnderlyingTokens[0] = GUSD;
        _gusdUnderlyingTokens[1] = THREE_CRV;
        setSwapPoolToLiquidityPoolToken(GUSD_SWAP_POOL, GUSD_THREE_CRV);
        setSwapPoolToUnderlyingTokens(GUSD_SWAP_POOL, _gusdUnderlyingTokens);

        address[] memory _husdUnderlyingTokens = new address[](2);
        _husdUnderlyingTokens[0] = HUSD;
        _husdUnderlyingTokens[1] = THREE_CRV;
        setSwapPoolToLiquidityPoolToken(HUSD_SWAP_POOL, HUSD_THREE_CRV);
        setSwapPoolToUnderlyingTokens(HUSD_SWAP_POOL, _husdUnderlyingTokens);

        address[] memory _usdkUnderlyingTokens = new address[](2);
        _usdkUnderlyingTokens[0] = USDK;
        _usdkUnderlyingTokens[1] = THREE_CRV;
        setSwapPoolToLiquidityPoolToken(USDK_SWAP_POOL, USDK_THREE_CRV);
        setSwapPoolToUnderlyingTokens(USDK_SWAP_POOL, _usdkUnderlyingTokens);

        address[] memory _usdnUnderlyingTokens = new address[](2);
        _usdnUnderlyingTokens[0] = USDN;
        _usdnUnderlyingTokens[1] = THREE_CRV;
        setSwapPoolToLiquidityPoolToken(USDN_SWAP_POOL, USDN_THREE_CRV);
        setSwapPoolToUnderlyingTokens(USDN_SWAP_POOL, _usdnUnderlyingTokens);

        address[] memory _linkusdUnderlyingTokens = new address[](2);
        _linkusdUnderlyingTokens[0] = LINKUSD;
        _linkusdUnderlyingTokens[1] = THREE_CRV;
        setSwapPoolToLiquidityPoolToken(LINKUSD_SWAP_POOL, LINKUSD_THREE_CRV);
        setSwapPoolToUnderlyingTokens(LINKUSD_SWAP_POOL, _linkusdUnderlyingTokens);

        address[] memory _musdUnderlyingTokens = new address[](2);
        _musdUnderlyingTokens[0] = MUSD;
        _musdUnderlyingTokens[1] = THREE_CRV;
        setSwapPoolToLiquidityPoolToken(MUSD_SWAP_POOL, MUSD_THREE_CRV);
        setSwapPoolToUnderlyingTokens(MUSD_SWAP_POOL, _musdUnderlyingTokens);

        address[] memory _rsvUnderlyingTokens = new address[](2);
        _rsvUnderlyingTokens[0] = RSV;
        _rsvUnderlyingTokens[1] = THREE_CRV;
        setSwapPoolToLiquidityPoolToken(RSV_SWAP_POOL, RSV_THREE_CRV);
        setSwapPoolToUnderlyingTokens(RSV_SWAP_POOL, _rsvUnderlyingTokens);

        address[] memory _tbtcUnderlyingTokens = new address[](2);
        _tbtcUnderlyingTokens[0] = TBTC;
        _tbtcUnderlyingTokens[1] = CRV_REN_BTC_WBTC_SBTC;
        setSwapPoolToLiquidityPoolToken(TBTC_SWAP_POOL, TBTC_SBTC_CRV);
        setSwapPoolToUnderlyingTokens(TBTC_SWAP_POOL, _tbtcUnderlyingTokens);

        address[] memory _dusdUnderlyingTokens = new address[](2);
        _dusdUnderlyingTokens[0] = DUSD;
        _dusdUnderlyingTokens[1] = THREE_CRV;
        setSwapPoolToLiquidityPoolToken(DUSD_SWAP_POOL, DUSD_THREE_CRV);
        setSwapPoolToUnderlyingTokens(DUSD_SWAP_POOL, _dusdUnderlyingTokens);

        setSwapPoolToGauges(COMPOUND_SWAP_POOL, address(0x7ca5b0a2910B33e9759DC7dDB0413949071D7575));
        setSwapPoolToGauges(USDT_SWAP_POOL, address(0xBC89cd85491d81C6AD2954E6d0362Ee29fCa8F53));
        setSwapPoolToGauges(PAX_SWAP_POOL, address(0x64E3C23bfc40722d3B649844055F1D51c1ac041d));
        setSwapPoolToGauges(Y_SWAP_POOL, address(0xFA712EE4788C042e2B7BB55E6cb8ec569C4530c1));
        setSwapPoolToGauges(BUSD_SWAP_POOL, address(0x69Fb7c45726cfE2baDeE8317005d3F94bE838840));
        setSwapPoolToGauges(SUSD_SWAP_POOL, address(0xA90996896660DEcC6E997655E065b23788857849));
        setSwapPoolToGauges(REN_SWAP_POOL, address(0xB1F2cdeC61db658F091671F5f199635aEF202CAC));
        setSwapPoolToGauges(SBTC_SWAP_POOL, address(0x705350c4BcD35c9441419DdD5d2f097d7a55410F));
        setSwapPoolToGauges(HBTC_SWAP_POOL, address(0x4c18E409Dc8619bFb6a1cB56D114C3f592E0aE79));
        setSwapPoolToGauges(THREE_SWAP_POOL, address(0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A));
        setSwapPoolToGauges(GUSD_SWAP_POOL, address(0xC5cfaDA84E902aD92DD40194f0883ad49639b023));
        setSwapPoolToGauges(HUSD_SWAP_POOL, address(0x2db0E83599a91b508Ac268a6197b8B14F5e72840));
        setSwapPoolToGauges(USDK_SWAP_POOL, address(0xC2b1DF84112619D190193E48148000e3990Bf627));
        setSwapPoolToGauges(USDN_SWAP_POOL, address(0xF98450B5602fa59CC66e1379DFfB6FDDc724CfC4));
        setSwapPoolToGauges(MUSD_SWAP_POOL, address(0x5f626c30EC1215f4EdCc9982265E8b1F411D1352));
        setSwapPoolToGauges(RSV_SWAP_POOL, address(0x4dC4A289a8E33600D8bD4cf5F6313E43a37adec7));
        setSwapPoolToGauges(TBTC_SWAP_POOL, address(0x6828bcF74279eE32f2723eC536c22c51Eed383C6));
        setSwapPoolToGauges(DUSD_SWAP_POOL, address(0xAEA6c312f4b3E04D752946d329693F7293bC2e6D));

        setMaxDepositPoolPctDefault(uint256(5000)); // 50%
    }

    /**
     * @inheritdoc IAdapter
     */
    function setMaxDepositPoolPct(address _liquidityPool, uint256 _maxDepositPoolPct) external override onlyGovernance {
        maxDepositPoolPct[_liquidityPool] = _maxDepositPoolPct;
    }

    /**
     * @inheritdoc IAdapterCurveInvestLimit
     */
    function setMaxDepositAmountDefault(uint256[4] memory _maxDepositAmountDefault) external override onlyGovernance {
        maxDepositAmountDefault = _maxDepositAmountDefault;
    }

    /**
     * @inheritdoc IAdapterCurveInvestLimit
     */
    function setMaxDeposit2Amount(address _liquidityPool, uint256[2] memory _maxDepositAmount)
        external
        override
        onlyGovernance
    {
        maxDeposit2Amount[_liquidityPool] = _maxDepositAmount;
    }

    /**
     * @inheritdoc IAdapterCurveInvestLimit
     */
    function setMaxDeposit3Amount(address _liquidityPool, uint256[3] memory _maxDepositAmount)
        external
        override
        onlyGovernance
    {
        maxDeposit3Amount[_liquidityPool] = _maxDepositAmount;
    }

    /**
     * @inheritdoc IAdapterCurveInvestLimit
     */
    function setMaxDeposit4Amount(address _liquidityPool, uint256[4] memory _maxDepositAmount)
        external
        override
        onlyGovernance
    {
        maxDeposit4Amount[_liquidityPool] = _maxDepositAmount;
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function setRewardToken(address _rewardToken) public override onlyOperator {
        rewardToken = _rewardToken;
    }

    /**
     * @notice Maps the curve swap pool with the liquidity pool token
     * @param _swapPool Curve's Swap pool address
     * @param _liquidityPoolToken liquidity pool's token address
     */
    function setSwapPoolToLiquidityPoolToken(address _swapPool, address _liquidityPoolToken) public onlyOperator {
        swapPoolToLiquidityPoolToken[_swapPool] = _liquidityPoolToken;
    }

    /**
     * @notice Maps the curve liquidity pool with the list of supported underlying tokens
     * @param _swapPool Curve's liquidity pool address
     * @param _tokens liquidity pool's token address
     */
    function setSwapPoolToUnderlyingTokens(address _swapPool, address[] memory _tokens) public onlyOperator {
        swapPoolToUnderlyingTokens[_swapPool] = _tokens;
    }

    /**
     * @notice Maps the curve swap pool with its gauge contract address
     * @param _pool Curve's Swap pool address
     * @param _gauge Curve's gauge contract address corresponding to the given swap pool
     */
    function setSwapPoolToGauges(address _pool, address _gauge) public onlyOperator {
        swapPoolToGauges[_pool] = _gauge;
    }

    /**
     * @dev Store's boolean whether curve's swap pool contracts has ability to remove liquidity for a single coin or not
     * @param _pool Curve's Swap pool address
     */
    function toggleNoRemoveLiquidityOneCoin(address _pool) public onlyOperator {
        if (!noRemoveLiquidityOneCoin[_pool]) {
            noRemoveLiquidityOneCoin[_pool] = true;
        } else {
            noRemoveLiquidityOneCoin[_pool] = false;
        }
    }

    /**
     * @inheritdoc IAdapterProtocolConfig
     */
    function setHarvestCodeProvider(address _harvestCodeProvider) public override onlyOperator {
        harvestCodeProviderContract = HarvestCodeProvider(_harvestCodeProvider);
    }

    /**
     * @inheritdoc IAdapter
     */
    function setMaxDepositPoolPctDefault(uint256 _maxDepositPoolPctDefault) public override onlyGovernance {
        maxDepositPoolPctDefault = _maxDepositPoolPctDefault;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getDepositAllCodes(
        address payable _vault,
        address[] memory,
        address _liquidityPool
    ) public view override returns (bytes[] memory _codes) {
        address[] memory _underlyingTokens = _getUnderlyingTokens(_liquidityPool);
        uint256 nCoins = _underlyingTokens.length;
        uint256[] memory _amounts = new uint256[](nCoins);
        for (uint256 i = 0; i < nCoins; i++) {
            _amounts[i] = IERC20(_underlyingTokens[i]).balanceOf(_vault);
        }
        return getDepositSomeCodes(_vault, _underlyingTokens, _liquidityPool, _amounts);
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
        _underlyingTokens = swapPoolToUnderlyingTokens[_liquidityPool];
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
        if (swapPoolToGauges[_liquidityPool] != address(0)) {
            _codes = new bytes[](1);
            _codes[0] = abi.encode(
                getMinter(swapPoolToGauges[_liquidityPool]),
                abi.encodeWithSignature("mint(address)", swapPoolToGauges[_liquidityPool])
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
        uint256 _rewardTokenAmount = IERC20(getRewardToken(_liquidityPool)).balanceOf(_vault);
        return getHarvestSomeCodes(_vault, _underlyingToken, _liquidityPool, _rewardTokenAmount);
    }

    /**
     * @inheritdoc IAdapter
     */
    function canStake(address _liquidityPool) public view override returns (bool) {
        if (swapPoolToGauges[_liquidityPool] != address(0)) {
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
        address[] memory,
        address _liquidityPool,
        uint256[] memory _amounts
    ) public view override returns (bytes[] memory _codes) {
        address[] memory _underlyingTokens = _getUnderlyingTokens(_liquidityPool);
        uint256 nCoins = _underlyingTokens.length;
        require(_amounts.length == nCoins, "!_amounts.length");
        if (nCoins == uint256(2)) {
            _codes = _getDeposit2Code(_underlyingTokens, _liquidityPool, _amounts);
        } else if (nCoins == uint256(3)) {
            _codes = _getDeposit3Code(_underlyingTokens, _liquidityPool, _amounts);
        } else if (nCoins == uint256(4)) {
            _codes = _getDeposit4Code(_underlyingTokens, _liquidityPool, _amounts);
        }
    }

    /**
     * @inheritdoc IAdapter
     */
    function getWithdrawSomeCodes(
        address payable,
        address[] memory _underlyingTokens,
        address _liquidityPool,
        uint256 _amount
    ) public view override returns (bytes[] memory _codes) {
        uint256 nCoins = _underlyingTokens.length;
        if (nCoins == uint256(1)) {
            _codes = _getWithdraw1Code(_underlyingTokens[0], _liquidityPool, _amount);
        } else if (nCoins == uint256(2)) {
            _codes = _getWithdraw2Code(_liquidityPool, _amount);
        } else if (nCoins == uint256(3)) {
            _codes = _getWithdraw3Code(_liquidityPool, _amount);
        } else if (nCoins == uint256(4)) {
            _codes = _getWithdraw4Code(_liquidityPool, _amount);
        }
    }

    /**
     * @inheritdoc IAdapter
     * @dev Reverting '!empty' message as there is no related functionality for this in CurveSwap pool
     */
    function getPoolValue(address, address) public view override returns (uint256) {
        revert("!empty");
    }

    /**
     * @inheritdoc IAdapter
     */
    function getLiquidityPoolToken(address, address _liquidityPool) public view override returns (address) {
        return swapPoolToLiquidityPoolToken[_liquidityPool];
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
        return IERC20(getLiquidityPoolToken(_underlyingToken, _liquidityPool)).balanceOf(_vault);
    }

    /**
     * @inheritdoc IAdapter
     */
    function getSomeAmountInToken(
        address _underlyingToken,
        address _liquidityPool,
        uint256 _liquidityPoolTokenAmount
    ) public view override returns (uint256) {
        address[] memory _underlyingTokens = _getUnderlyingTokens(_liquidityPool);
        uint256 tokenIndex = 0;
        for (uint256 i = 0; i < _underlyingTokens.length; i++) {
            if (_underlyingTokens[i] == _underlyingToken) {
                tokenIndex = i;
            }
        }
        if (_liquidityPoolTokenAmount > 0) {
            return ICurveDeposit(_liquidityPool).calc_withdraw_one_coin(_liquidityPoolTokenAmount, int128(tokenIndex));
        }
        return 0;
    }

    /**
     * @inheritdoc IAdapter
     */
    function getRewardToken(address _liquidityPool) public view override returns (address) {
        if (swapPoolToGauges[_liquidityPool] != address(0)) {
            return rewardToken;
        }
        return address(0);
    }

    /**
     * @inheritdoc IAdapterHarvestReward
     */
    function getUnclaimedRewardTokenAmount(address payable, address _liquidityPool)
        public
        view
        override
        returns (uint256)
    {
        /* solhint-disable no-empty-blocks */
        if (swapPoolToGauges[_liquidityPool] != address(0)) {
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
            harvestCodeProviderContract.getHarvestCodes(
                _vault,
                getRewardToken(_liquidityPool),
                _underlyingToken,
                _rewardTokenAmount
            );
    }

    /**
     * @inheritdoc IAdapterStaking
     */
    function getStakeSomeCodes(address _liquidityPool, uint256 _stakeAmount)
        public
        view
        override
        returns (bytes[] memory _codes)
    {
        address _gauge = swapPoolToGauges[_liquidityPool];
        address _liquidityPoolToken = getLiquidityPoolToken(address(0), _liquidityPool);
        _codes = new bytes[](3);
        _codes[0] = abi.encode(
            _liquidityPoolToken,
            abi.encodeWithSignature("approve(address,uint256)", _gauge, uint256(0))
        );
        _codes[1] = abi.encode(
            _liquidityPoolToken,
            abi.encodeWithSignature("approve(address,uint256)", _gauge, _stakeAmount)
        );
        _codes[2] = abi.encode(_gauge, abi.encodeWithSignature("deposit(uint256)", _stakeAmount));
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
        address _gauge = swapPoolToGauges[_liquidityPool];
        _codes = new bytes[](1);
        _codes[0] = abi.encode(_gauge, abi.encodeWithSignature("withdraw(uint256)", _unstakeAmount));
    }

    /**
     * @inheritdoc IAdapterStaking
     */
    function getAllAmountInTokenStake(
        address payable _vault,
        address _underlyingToken,
        address _liquidityPool
    ) public view override returns (uint256) {
        address[] memory _underlyingTokens = _getUnderlyingTokens(_liquidityPool);
        uint256 tokenIndex = 0;
        for (uint256 i = 0; i < _underlyingTokens.length; i++) {
            if (_underlyingTokens[i] == _underlyingToken) {
                tokenIndex = i;
            }
        }
        uint256 _liquidityPoolTokenAmount = getLiquidityPoolTokenBalanceStake(_vault, _liquidityPool);
        uint256 _b = 0;
        if (_liquidityPoolTokenAmount > 0) {
            _b = ICurveDeposit(_liquidityPool).calc_withdraw_one_coin(_liquidityPoolTokenAmount, int128(tokenIndex));
        }
        _b = _b.add(
            harvestCodeProviderContract.rewardBalanceInUnderlyingTokens(
                getRewardToken(_liquidityPool),
                _underlyingToken,
                getUnclaimedRewardTokenAmount(_vault, _liquidityPool)
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
        return ICurveGauge(swapPoolToGauges[_liquidityPool]).balanceOf(_vault);
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
     * @dev Deploy function for a pool with 2 tokens
     */
    function _getDeposit2Code(
        address[] memory _underlyingTokens,
        address _liquidityPool,
        uint256[] memory _amounts
    ) internal view returns (bytes[] memory _codes) {
        uint256[2] memory _amountsIn;
        uint256[] memory _amountsAux = new uint256[](2);
        uint8 _codeLength = 1;
        bool _isAmount = false;
        // calculator for lines of code
        for (uint8 i = 0; i < 2; i++) {
            _amountsIn[i] = _amounts[i];
            if (_amountsIn[i] > 0) {
                if (_underlyingTokens[i] == HBTC) {
                    _codeLength++;
                } else {
                    _codeLength += 2;
                }
            }
        }
        _amountsAux = _getDeposit2Amount(_liquidityPool, _amounts);
        _codes = new bytes[](_codeLength);
        uint8 _j = 0;
        for (uint8 i = 0; i < 2; i++) {
            _amountsIn[i] = _amountsAux[i];
            if (_amountsIn[i] > 0) {
                _isAmount = true;
                if (_underlyingTokens[i] == HBTC) {
                    _codes[_j++] = abi.encode(
                        _underlyingTokens[i],
                        abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, _amountsIn[i])
                    );
                } else {
                    _codes[_j++] = abi.encode(
                        _underlyingTokens[i],
                        abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, uint256(0))
                    );
                    _codes[_j++] = abi.encode(
                        _underlyingTokens[i],
                        abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, _amountsIn[i])
                    );
                }
            }
        }
        if (_isAmount) {
            _codes[_j] = abi.encode(
                _liquidityPool,
                abi.encodeWithSignature("add_liquidity(uint256[2],uint256)", _amountsIn, uint256(0))
            );
        }
    }

    /**
     * @dev Deploy function for a pool with 3 tokens
     */
    function _getDeposit3Code(
        address[] memory _underlyingTokens,
        address _liquidityPool,
        uint256[] memory _amounts
    ) internal view returns (bytes[] memory _codes) {
        uint256[3] memory _amountsIn;
        uint256[] memory _amountsAux = new uint256[](3);
        uint8 _codeLength = 1;
        bool _isAmount = false;
        // calculator for lines of code
        for (uint8 i = 0; i < 3; i++) {
            _amountsIn[i] = _amounts[i];
            if (_amountsIn[i] > 0) {
                if (_underlyingTokens[i] == HBTC) {
                    _codeLength++;
                } else {
                    _codeLength += 2;
                }
            }
        }
        _amountsAux = _getDeposit3Amount(_liquidityPool, _amounts);
        _codes = new bytes[](_codeLength);
        uint8 _j = 0;
        for (uint8 i = 0; i < 3; i++) {
            _amountsIn[i] = _amountsAux[i];
            if (_amountsIn[i] > 0) {
                _isAmount = true;
                if (_underlyingTokens[i] == HBTC) {
                    _codes[_j++] = abi.encode(
                        _underlyingTokens[i],
                        abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, _amountsIn[i])
                    );
                } else {
                    _codes[_j++] = abi.encode(
                        _underlyingTokens[i],
                        abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, uint256(0))
                    );
                    _codes[_j++] = abi.encode(
                        _underlyingTokens[i],
                        abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, _amountsIn[i])
                    );
                }
            }
        }
        if (_isAmount) {
            _codes[_j] = abi.encode(
                _liquidityPool,
                abi.encodeWithSignature("add_liquidity(uint256[3],uint256)", _amountsIn, uint256(0))
            );
        }
    }

    /**
     * @dev Deploy function for a pool with 4 tokens
     */
    function _getDeposit4Code(
        address[] memory _underlyingTokens,
        address _liquidityPool,
        uint256[] memory _amounts
    ) internal view returns (bytes[] memory _codes) {
        uint256[2] memory _amountsIn;
        uint256[] memory _amountsAux = new uint256[](4);
        uint8 _codeLength = 1;
        bool _isAmount = false;
        // calculator for lines of code
        for (uint8 i = 0; i < 4; i++) {
            _amountsIn[i] = _amounts[i];
            if (_amountsIn[i] > 0) {
                if (_underlyingTokens[i] == HBTC) {
                    _codeLength++;
                } else {
                    _codeLength += 2;
                }
            }
        }
        _amountsAux = _getDeposit4Amount(_liquidityPool, _amounts);
        _codes = new bytes[](_codeLength);
        uint8 _j = 0;
        for (uint8 i = 0; i < 4; i++) {
            _amountsIn[i] = _amountsAux[i];
            if (_amountsIn[i] > 0) {
                _isAmount = true;
                if (_underlyingTokens[i] == HBTC) {
                    _codes[_j++] = abi.encode(
                        _underlyingTokens[i],
                        abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, _amountsIn[i])
                    );
                } else {
                    _codes[_j++] = abi.encode(
                        _underlyingTokens[i],
                        abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, uint256(0))
                    );
                    _codes[_j++] = abi.encode(
                        _underlyingTokens[i],
                        abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, _amountsIn[i])
                    );
                }
            }
        }
        if (_isAmount) {
            _codes[_j] = abi.encode(
                _liquidityPool,
                abi.encodeWithSignature("add_liquidity(uint256[4],uint256)", _amountsIn, uint256(0))
            );
        }
    }

    /**
     * @dev Swaps _amount of _liquidityPoolToken for a certain quantity of each underlying token
     */
    function _getWithdraw1Code(
        address _underlyingToken,
        address _liquidityPool,
        uint256 _amount
    ) internal view returns (bytes[] memory _codes) {
        if (_amount > 0) {
            address[] memory _underlyingTokens = _getUnderlyingTokens(_liquidityPool);
            uint256 i = 0;
            for (uint256 j = 0; j < _underlyingTokens.length; j++) {
                if (_underlyingTokens[j] == _underlyingToken) {
                    i = j;
                }
            }
            address _liquidityPoolToken = getLiquidityPoolToken(address(0), _liquidityPool);
            _codes = new bytes[](3);
            if (!noRemoveLiquidityOneCoin[_liquidityPool]) {
                _codes[0] = abi.encode(
                    _liquidityPoolToken,
                    abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, uint256(0))
                );
                _codes[1] = abi.encode(
                    _liquidityPoolToken,
                    abi.encodeWithSignature("approve(address,uint256)", _liquidityPool, _amount)
                );
                _codes[2] = abi.encode(
                    _liquidityPool,
                    // solhint-disable-next-line max-line-length
                    abi.encodeWithSignature("remove_liquidity_one_coin(uint256,int128,uint256)", _amount, i, uint256(0))
                );
            } else {
                // Note : swap pools of compound,usdt,pax,y,susd and busd
                //        does not have remove_liquidity_one_coin function
                revert("!remove_one_coin");
            }
        }
    }

    /**
     * @dev Swaps _amount of _liquidityPoolToken for a certain quantity of each underlying token
     */
    function _getWithdraw2Code(address _liquidityPool, uint256 _amount) internal view returns (bytes[] memory _codes) {
        if (_amount > 0) {
            uint256[2] memory _minAmountOut = [uint256(0), uint256(0)];
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
            _codes[2] = abi.encode(
                _liquidityPool,
                abi.encodeWithSignature("remove_liquidity(uint256,uint256[2])", _amount, _minAmountOut)
            );
        }
    }

    /**
     * @dev Swaps _amount of _liquidityPoolToken for a certain quantity of each underlying token
     */
    function _getWithdraw3Code(address _liquidityPool, uint256 _amount) internal view returns (bytes[] memory _codes) {
        if (_amount > 0) {
            uint256[3] memory _minAmountOut = [uint256(0), uint256(0), uint256(0)];
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
            _codes[2] = abi.encode(
                _liquidityPool,
                abi.encodeWithSignature("remove_liquidity(uint256,uint256[3])", _amount, _minAmountOut)
            );
        }
    }

    /**
     * @dev Swaps _amount of _liquidityPoolToken for a certain quantity of each underlying token
     */
    function _getWithdraw4Code(address _liquidityPool, uint256 _amount) internal view returns (bytes[] memory _codes) {
        if (_amount > 0) {
            uint256[4] memory _minAmountOut = [uint256(0), uint256(0), uint256(0), uint256(0)];
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
            _codes[2] = abi.encode(
                _liquidityPool,
                abi.encodeWithSignature("remove_liquidity(uint256,uint256[4])", _amount, _minAmountOut)
            );
        }
    }

    function _getDeposit2Amount(address _liquidityPool, uint256[] memory _amounts)
        internal
        view
        returns (uint256[] memory)
    {
        uint256[2] memory _maxDepositAmounts;
        uint256[] memory _depositAmounts = new uint256[](2);
        for (uint256 i = 0; i < 2; i++) {
            if ((maxDeposit2Amount[_liquidityPool])[i] == uint256(0)) {
                _maxDepositAmounts[i] = maxDepositAmountDefault[i];
            } else {
                _maxDepositAmounts[i] = maxDeposit2Amount[_liquidityPool][i];
            }
            if (_maxDepositAmounts[i] > _amounts[i]) {
                _depositAmounts[i] = _amounts[i];
            } else {
                _depositAmounts[i] = _maxDepositAmounts[i];
            }
        }
        return _depositAmounts;
    }

    function _getDeposit3Amount(address _liquidityPool, uint256[] memory _amounts)
        internal
        view
        returns (uint256[] memory)
    {
        uint256[3] memory _maxDepositAmounts;
        uint256[] memory _depositAmounts = new uint256[](3);
        for (uint256 i = 0; i < 3; i++) {
            if ((maxDeposit3Amount[_liquidityPool])[i] == uint256(0)) {
                _maxDepositAmounts[i] = maxDepositAmountDefault[i];
            } else {
                _maxDepositAmounts[i] = maxDeposit3Amount[_liquidityPool][i];
            }
            if (_maxDepositAmounts[i] > _amounts[i]) {
                _depositAmounts[i] = _amounts[i];
            } else {
                _depositAmounts[i] = _maxDepositAmounts[i];
            }
        }
        return _depositAmounts;
    }

    function _getDeposit4Amount(address _liquidityPool, uint256[] memory _amounts)
        internal
        view
        returns (uint256[] memory)
    {
        uint256[4] memory _maxDepositAmounts;
        uint256[] memory _depositAmounts = new uint256[](4);
        for (uint256 i = 0; i < 4; i++) {
            if ((maxDeposit4Amount[_liquidityPool])[i] == uint256(0)) {
                _maxDepositAmounts[i] = maxDepositAmountDefault[i];
            } else {
                _maxDepositAmounts[i] = maxDeposit4Amount[_liquidityPool][i];
            }
            if (_maxDepositAmounts[i] > _amounts[i]) {
                _depositAmounts[i] = _amounts[i];
            } else {
                _depositAmounts[i] = _maxDepositAmounts[i];
            }
        }
        return _depositAmounts;
    }

    function _getUnderlyingTokens(address _liquidityPool) internal view returns (address[] memory _underlyingTokens) {
        _underlyingTokens = swapPoolToUnderlyingTokens[_liquidityPool];
    }
}
