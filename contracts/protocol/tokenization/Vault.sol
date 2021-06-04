// SPDX-License-Identifier: MIT

pragma solidity ^0.6.10;
pragma experimental ABIEncoderV2;

// helper contracts
import { MultiCall } from "../../utils/MultiCall.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Deployer } from "../../dependencies/chi/ChiDeployer.sol";
import { VersionedInitializable } from "../../dependencies/openzeppelin/VersionedInitializable.sol";
import { IncentivisedERC20 } from "./IncentivisedERC20.sol";
import { Modifiers } from "../configuration/Modifiers.sol";
import { VaultStorage } from "./VaultStorage.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

// libraries
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { DataTypes } from "../../libraries/types/DataTypes.sol";

// interfaces
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IVault } from "../../interfaces/opty/IVault.sol";
import { IStrategyManager } from "../../interfaces/opty/IStrategyManager.sol";
import { IRegistry } from "../../interfaces/opty/IRegistry.sol";
import { IRiskManager } from "../../interfaces/opty/IRiskManager.sol";
import { IOPTYMinter } from "../../interfaces/opty/IOPTYMinter.sol";
import { IHarvestCodeProvider } from "../../interfaces/opty/IHarvestCodeProvider.sol";

/**
 * @title Vault contract inspired by AAVE V2's AToken.sol
 * @author opty.fi
 * @notice Implementation of the risk specific interest bearing vault
 */

contract Vault is
    VersionedInitializable,
    IVault,
    IncentivisedERC20,
    MultiCall,
    Modifiers,
    ReentrancyGuard,
    VaultStorage,
    Deployer
{
    using SafeERC20 for IERC20;
    using Address for address;

    /**
     * @notice
     * @dev
     */
    uint256 public constant opTOKEN_REVISION = 0x1;

    /* solhint-disable no-empty-blocks */
    constructor(
        address _registry,
        string memory _name,
        string memory _symbol,
        string memory _riskProfile
    )
        public
        IncentivisedERC20(
            string(abi.encodePacked("op ", _name, " ", _riskProfile, " vault")),
            string(abi.encodePacked("op", _symbol, _riskProfile, "Vault"))
        )
        Modifiers(_registry)
    {}

    /* solhint-disable no-empty-blocks */
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function initialize(
        address _registry,
        address _underlyingToken,
        string memory _name,
        string memory _symbol,
        string memory _riskProfile
    ) external virtual initializer {
        require(bytes(_name).length > 0, "Name_Empty!");
        require(bytes(_symbol).length > 0, "Symbol_Empty!");
        registryContract = IRegistry(_registry);
        setProfile(_riskProfile);
        setToken(_underlyingToken); //  underlying token contract address (for example DAI)
        _setName(string(abi.encodePacked("op ", _name, " ", _riskProfile, " vault")));
        _setSymbol(string(abi.encodePacked("op", _symbol, _riskProfile, "Vault")));
        _setDecimals(IncentivisedERC20(_underlyingToken).decimals());
    }

    /**
     * @inheritdoc
     */
    function setMaxVaultValueJump(uint256 _maxVaultValueJump) external override onlyGovernance returns (bool _success) {
        maxVaultValueJump = _maxVaultValueJump;
        _success = true;
    }

    /**
     * @inheritdoc IVault
     */
    function rebalance() external override ifNotPausedAndDiscontinued(address(this)) {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();

        uint256 _gasInitial = msg.sender == _vaultStrategyConfiguration.operator ? gasleft() : uint256(0);

        address[] memory _underlyingTokens = new address[](1);
        _underlyingTokens[0] = underlyingToken;
        bytes32 _newInvestStrategyHash =
            IRiskManager(_vaultStrategyConfiguration.riskManager).getBestStrategy(profile, _underlyingTokens);
        if (
            keccak256(abi.encodePacked(_newInvestStrategyHash)) != keccak256(abi.encodePacked(investStrategyHash)) &&
            investStrategyHash != ZERO_BYTES32
        ) {
            _withdrawAll(_vaultStrategyConfiguration);
            _harvest(investStrategyHash, _vaultStrategyConfiguration);
            if (msg.sender == _vaultStrategyConfiguration.operator && gasOwedToOperator != uint256(0)) {
                IERC20(underlyingToken).safeTransfer(
                    _vaultStrategyConfiguration.operator,
                    IHarvestCodeProvider(registryContract.getHarvestCodeProvider()).getWETHInToken(
                        underlyingToken,
                        gasOwedToOperator
                    )
                );
            }
        }

        investStrategyHash = _newInvestStrategyHash;
        if (_balance() > 0) {
            _emergencyBrake(_balance());
            investStrategyHash = IRiskManager(_vaultStrategyConfiguration.riskManager).getBestStrategy(
                profile,
                _underlyingTokens
            );
            _supplyAll(_vaultStrategyConfiguration);
        }

        if (msg.sender == _vaultStrategyConfiguration.operator) {
            gasOwedToOperator = gasOwedToOperator.add((_gasInitial.sub(gasleft())).mul(tx.gasprice));
        }
    }

    /**
     * @inheritdoc IVault
     */
    function harvest(bytes32 _investStrategyHash) external override {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        _harvest(_investStrategyHash, _vaultStrategyConfiguration);
    }

    /**
     * @inheritdoc IVault
     */
    function userDepositAll() external override {
        _userDeposit(IERC20(underlyingToken).balanceOf(msg.sender));
    }

    /**
     * @inheritdoc IVault
     */
    function userDeposit(uint256 _amount) external override returns (bool) {
        _userDeposit(_amount);
    }

    /**
     * @inheritdoc IVault
     */
    function userDepositAllRebalance() external override {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        _userDepositRebalance(IERC20(underlyingToken).balanceOf(msg.sender), _vaultStrategyConfiguration);
    }

    /**
     * @inheritdoc IVault
     */
    function userDepositRebalance(uint256 _amount) external override returns (bool) {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        _userDepositRebalance(_amount, _vaultStrategyConfiguration);
    }

    /**
     * @inheritdoc IVault
     */
    function userWithdrawAllRebalance() external override {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        _userWithdrawRebalance(balanceOf(msg.sender), _vaultStrategyConfiguration);
    }

    /**
     * @inheritdoc IVault
     */
    function userWithdrawRebalance(uint256 _redeemAmount) external override returns (bool) {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        _userWithdrawRebalance(_redeemAmount, _vaultStrategyConfiguration);
    }

    /**
     * @inheritdoc IVault
     */
    function userDepositAllWithCHI() external override discountCHI {
        _userDeposit(IERC20(underlyingToken).balanceOf(msg.sender));
    }

    /**
     * @inheritdoc IVault
     */
    function userDepositWithCHI(uint256 _amount) external override discountCHI {
        _userDeposit(_amount);
    }

    /**
     * @inheritdoc IVault
     */
    function userDepositAllRebalanceWithCHI() external override discountCHI {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        _userDepositRebalance(IERC20(underlyingToken).balanceOf(msg.sender), _vaultStrategyConfiguration);
    }

    /**
     * @inheritdoc IVault
     */
    function userDepositRebalanceWithCHI(uint256 _amount) external override discountCHI {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        _userDepositRebalance(_amount, _vaultStrategyConfiguration);
    }

    /**
     * @inheritdoc IVault
     */
    function userWithdrawRebalanceWithCHI(uint256 _redeemAmount) external override discountCHI {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        _userWithdrawRebalance(_redeemAmount, _vaultStrategyConfiguration);
    }

    /**
     * @inheritdoc IVault
     */
    function userWithdrawAllRebalanceWithCHI() external override discountCHI {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        _userWithdrawRebalance(balanceOf(msg.sender), _vaultStrategyConfiguration);
    }

    /**
     * @inheritdoc IVault
     */
    function discontinue() external override onlyRegistry {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        if (investStrategyHash != ZERO_BYTES32) {
            _withdrawAll(_vaultStrategyConfiguration);
            _harvest(investStrategyHash, _vaultStrategyConfiguration);
        }
    }

    /**
     * @inheritdoc IVault
     */
    function setUnpaused(bool _unpaused) external override onlyRegistry {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        if (!_unpaused && investStrategyHash != ZERO_BYTES32) {
            _withdrawAll(_vaultStrategyConfiguration);
            _harvest(investStrategyHash, _vaultStrategyConfiguration);
        }
    }

    /**
     * @inheritdoc IVault
     */
    function balance() public view override returns (uint256) {
        return _balance();
    }

    /**
     * @inheritdoc IVault
     */
    function getPricePerFullShare() public view override returns (uint256) {
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration =
            registryContract.getVaultStrategyConfiguration();
        if (totalSupply() != 0) {
            return _calVaultValueInUnderlyingToken(_vaultStrategyConfiguration).div(totalSupply());
        }
        return uint256(0);
    }

    /**
     * @inheritdoc IVault
     */
    function setProfile(string memory _profile) public override onlyOperator returns (bool _success) {
        require(bytes(_profile).length > 0, "Profile_Empty!");
        DataTypes.RiskProfile memory _riskProfile = registryContract.getRiskProfile(_profile);
        require(_riskProfile.exists, "!Rp_Exists");
        profile = _profile;
        _success = true;
    }

    /**
     * @inheritdoc IVault
     */
    function setToken(address _underlyingToken) public override onlyOperator returns (bool _success) {
        require(_underlyingToken.isContract(), "!_underlyingToken.isContract");
        require(registryContract.isApprovedToken(_underlyingToken), "!tokens");
        underlyingToken = _underlyingToken;
        _success = true;
    }

    /**
     * @inheritdoc IVault
     */
    function isMaxVaultValueJumpAllowed(uint256 _diff, uint256 _currentVaultValue) public view override returns (bool) {
        return (_diff.mul(10000)).div(_currentVaultValue) < maxVaultValueJump;
    }

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _supplyAll(DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration) internal {
        _batchMintAndBurn(_vaultStrategyConfiguration);
        uint8 _steps =
            IStrategyManager(_vaultStrategyConfiguration.strategyManager).getDepositAllStepCount(investStrategyHash);
        for (uint8 _i; _i < _steps; _i++) {
            executeCodes(
                IStrategyManager(_vaultStrategyConfiguration.strategyManager).getPoolDepositAllCodes(
                    payable(address(this)),
                    underlyingToken,
                    investStrategyHash,
                    _i,
                    _steps
                ),
                "!_supplyAll"
            );
        }
        vaultValue = _calVaultValueInUnderlyingToken(_vaultStrategyConfiguration);
    }

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _withdrawAll(DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration) internal {
        uint8 _steps =
            IStrategyManager(_vaultStrategyConfiguration.strategyManager).getWithdrawAllStepsCount(investStrategyHash);
        for (uint8 _i; _i < _steps; _i++) {
            uint8 _iterator = _steps - 1 - _i;
            executeCodes(
                IStrategyManager(_vaultStrategyConfiguration.strategyManager).getPoolWithdrawAllCodes(
                    payable(address(this)),
                    underlyingToken,
                    investStrategyHash,
                    _iterator,
                    _steps
                ),
                "!_withdrawAll"
            );
        }
    }

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _harvest(
        bytes32 _investStrategyHash,
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration
    ) internal {
        address _rewardToken =
            IStrategyManager(_vaultStrategyConfiguration.strategyManager).getRewardToken(_investStrategyHash);
        if (_rewardToken != address(0)) {
            // means rewards exists
            executeCodes(
                IStrategyManager(_vaultStrategyConfiguration.strategyManager).getPoolClaimAllRewardCodes(
                    payable(address(this)),
                    _investStrategyHash
                ),
                "!claim"
            );
            executeCodes(
                IStrategyManager(_vaultStrategyConfiguration.strategyManager).getPoolHarvestSomeRewardCodes(
                    payable(address(this)),
                    underlyingToken,
                    _investStrategyHash,
                    IRiskManager(_vaultStrategyConfiguration.riskManager).getVaultRewardTokenStrategy(
                        keccak256(abi.encodePacked([address(this), _rewardToken]))
                    )
                ),
                "!harvest"
            );
        }
    }

    /**
     * @dev Function for depositing underlying tokens (for example DAI) into the contract
     *
     * Requirements:
     *
     *  - Amount should be greater than 0
     *  - Amount is in wad units, Eg: _amount = 1e18 wad means _amount = 1 DAI
     */
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _userDeposit(uint256 _amount)
        internal
        ifNotPausedAndDiscontinued(address(this))
        nonReentrant
        returns (bool _success)
    {
        require(_amount > 0, "!(_amount>0)");
        IERC20(underlyingToken).safeTransferFrom(msg.sender, address(this), _amount);
        queue.push(DataTypes.Operation(msg.sender, true, _amount));
        pendingDeposits[msg.sender] += _amount;
        depositQueue += _amount;
        emit DepositQueue(msg.sender, queue.length, _amount);
        _success = true;
    }

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _batchMintAndBurn(DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration)
        internal
        returns (bool _success)
    {
        for (uint256 i; i < queue.length; i++) {
            if (queue[i].isDeposit) {
                _mintShares(queue[i].account, _balance(), queue[i].value);
                pendingDeposits[msg.sender] -= queue[i].value;
                depositQueue -= queue[i].value;
            } else {
                _redeemAndBurn(queue[i].account, _balance(), queue[i].value, _vaultStrategyConfiguration);
                pendingWithdraws[msg.sender] -= queue[i].value;
                withdrawQueue -= queue[i].value;
            }
            IOPTYMinter(_vaultStrategyConfiguration.optyMinter).updateUserStateInVault(address(this), queue[i].account);
        }
        IOPTYMinter(_vaultStrategyConfiguration.optyMinter).updateOptyVaultRatePerSecondAndVaultToken(address(this));
        IOPTYMinter(_vaultStrategyConfiguration.optyMinter).updateOptyVaultIndex(address(this));
        delete queue;
        _success = true;
    }

    /**
     * @dev Depositing asset like DAI and minting op tokens to caller
     *
     * Requirements:
     *
     *  - Amount should be greater than 0
     *  - Amount is in wad units, Eg: _amount = 1e18 wad means _amount = 1 DAI
     */
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _userDepositRebalance(
        uint256 _amount,
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration
    ) internal ifNotPausedAndDiscontinued(address(this)) nonReentrant returns (bool _success) {
        require(_amount > 0, "!(_amount>0)");

        if (investStrategyHash != ZERO_BYTES32) {
            _withdrawAll(_vaultStrategyConfiguration);
            _harvest(investStrategyHash, _vaultStrategyConfiguration);
        }

        uint256 _tokenBalanceBefore = _balance();
        IERC20(underlyingToken).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _tokenBalanceAfter = _balance();
        uint256 _tokenBalanceDiff = _tokenBalanceAfter.sub(_tokenBalanceBefore);

        uint256 shares = 0;

        if (_tokenBalanceBefore == 0 || totalSupply() == 0) {
            shares = _tokenBalanceDiff;
        } else {
            shares = (_tokenBalanceDiff.mul(totalSupply())).div((_tokenBalanceBefore));
        }

        IOPTYMinter(_vaultStrategyConfiguration.optyMinter).updateUserRewards(address(this), msg.sender);
        _mint(msg.sender, shares);
        IOPTYMinter(_vaultStrategyConfiguration.optyMinter).updateOptyVaultRatePerSecondAndVaultToken(address(this));
        IOPTYMinter(_vaultStrategyConfiguration.optyMinter).updateOptyVaultIndex(address(this));
        IOPTYMinter(_vaultStrategyConfiguration.optyMinter).updateUserStateInVault(address(this), msg.sender);
        if (_balance() > 0) {
            _emergencyBrake(_balance());
            address[] memory _underlyingTokens = new address[](1);
            _underlyingTokens[0] = underlyingToken;
            investStrategyHash = IRiskManager(_vaultStrategyConfiguration.riskManager).getBestStrategy(
                profile,
                _underlyingTokens
            );
            _supplyAll(_vaultStrategyConfiguration);
        }
        _success = true;
    }

    /**
     * @dev Function to withdraw the vault tokens from the vault (for example cDAI)
     *
     * Requirements:
     *  -   contract function will be called.
     *  -   _redeemAmount: amount to withdraw from the vault. Its units are:
     *      in weth uints i.e. 1e18
     */
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _userWithdrawRebalance(
        uint256 _redeemAmount,
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration
    ) internal nonReentrant returns (bool) {
        DataTypes.VaultConfiguration memory _vaultConfiguration = registryContract.getVaultConfiguration(address(this));
        require(_vaultConfiguration.unpaused, "unpause");
        require(_redeemAmount > 0, "!_redeemAmount>0");
        uint256 opBalance = balanceOf(msg.sender);
        require(_redeemAmount <= opBalance, "!!balance");
        if (!_vaultConfiguration.discontinued && investStrategyHash != ZERO_BYTES32) {
            _withdrawAll(_vaultStrategyConfiguration);
            _harvest(investStrategyHash, _vaultStrategyConfiguration);
        }
        IOPTYMinter(_vaultStrategyConfiguration.optyMinter).updateUserRewards(address(this), msg.sender);
        // subtract pending deposit from total balance
        _redeemAndBurn(msg.sender, _balance().sub(depositQueue), _redeemAmount, _vaultStrategyConfiguration);

        IOPTYMinter(_vaultStrategyConfiguration.optyMinter).updateOptyVaultRatePerSecondAndVaultToken(address(this));
        IOPTYMinter(_vaultStrategyConfiguration.optyMinter).updateOptyVaultIndex(address(this));
        IOPTYMinter(_vaultStrategyConfiguration.optyMinter).updateUserStateInVault(address(this), msg.sender);

        if (!_vaultConfiguration.discontinued && (_balance() > 0)) {
            _emergencyBrake(_balance());
            address[] memory _underlyingTokens = new address[](1);
            _underlyingTokens[0] = underlyingToken;
            investStrategyHash = IRiskManager(_vaultStrategyConfiguration.riskManager).getBestStrategy(
                profile,
                _underlyingTokens
            );
            _supplyAll(_vaultStrategyConfiguration);
        }
        return true;
    }

    /**
     * @inheritdoc IncentivisedERC20
     */
    function _beforeTokenTransfer(
        address from,
        address,
        uint256
    ) internal override {
        executeCodes(
            IStrategyManager(registryContract.getStrategyManager()).getUserRewardCodes(address(this), from),
            "!_beforeTokenTransfer"
        );
    }

    /**
     * @dev Function to calculate vault value in underlying token (for example DAI)
     *
     * Note:
     *  - Need to modify this function in future whenever 2nd layer of depositing
     *    the underlying token (for example DAI) into any
     *    credit pool like compound is added.
     */
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _calVaultValueInUnderlyingToken(DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration)
        internal
        view
        returns (uint256)
    {
        if (investStrategyHash != ZERO_BYTES32) {
            uint256 balanceInUnderlyingToken =
                IStrategyManager(_vaultStrategyConfiguration.strategyManager).getBalanceInUnderlyingToken(
                    payable(address(this)),
                    underlyingToken,
                    investStrategyHash
                );
            return balanceInUnderlyingToken.add(_balance()).sub(depositQueue);
        }
        return _balance().sub(depositQueue);
    }

    /**
     * @dev Internal function to get the underlying token balance of OptyVault Contract
     */
    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _balance() internal view returns (uint256) {
        return IERC20(underlyingToken).balanceOf(address(this));
    }

    /**
     * @inheritdoc
     */
    function getRevision() internal pure virtual override returns (uint256) {
        return opTOKEN_REVISION;
    }

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _abs(uint256 _a, uint256 _b) internal pure returns (uint256) {
        if (_a > _b) {
            return _a.sub(_b);
        }
        return _b.sub(_a);
    }

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _emergencyBrake(uint256 _vaultValue) private returns (bool) {
        uint256 _blockTransactions = blockToBlockVaultValues[block.number].length;
        if (_blockTransactions > 0) {
            blockToBlockVaultValues[block.number].push(
                DataTypes.BlockVaultValue({
                    actualVaultValue: _vaultValue,
                    blockMinVaultValue: _vaultValue <
                        blockToBlockVaultValues[block.number][_blockTransactions - 1].blockMinVaultValue
                        ? _vaultValue
                        : blockToBlockVaultValues[block.number][_blockTransactions - 1].blockMinVaultValue,
                    blockMaxVaultValue: _vaultValue >
                        blockToBlockVaultValues[block.number][_blockTransactions - 1].blockMaxVaultValue
                        ? _vaultValue
                        : blockToBlockVaultValues[block.number][_blockTransactions - 1].blockMaxVaultValue
                })
            );
            require(
                isMaxVaultValueJumpAllowed(
                    _abs(
                        blockToBlockVaultValues[block.number][_blockTransactions].blockMinVaultValue,
                        blockToBlockVaultValues[block.number][_blockTransactions].blockMaxVaultValue
                    ),
                    _vaultValue
                ),
                "!maxVaultValueJump"
            );
        } else {
            blockToBlockVaultValues[block.number].push(
                DataTypes.BlockVaultValue({
                    actualVaultValue: _vaultValue,
                    blockMinVaultValue: _vaultValue,
                    blockMaxVaultValue: _vaultValue
                })
            );
        }
    }

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _redeemAndBurn(
        address _account,
        uint256 _balanceInUnderlyingToken,
        uint256 _redeemAmount,
        DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration
    ) private {
        uint256 redeemAmountInToken = (_balanceInUnderlyingToken.mul(_redeemAmount)).div(totalSupply());
        //  Updating the totalSupply of op tokens
        _burn(msg.sender, _redeemAmount);
        executeCodes(
            IStrategyManager(_vaultStrategyConfiguration.strategyManager).getSplitPaymentCode(
                registryContract.getTreasuryShares(address(this)),
                _account,
                underlyingToken,
                redeemAmountInToken
            ),
            "!TreasuryRedeemAmt"
        );
    }

    /**
     * @notice
     * @dev
     * @param
     * @param
     * @param
     * @return
     */
    function _mintShares(
        address _account,
        uint256 _balanceInUnderlyingToken,
        uint256 _depositAmount
    ) private {
        if (_balanceInUnderlyingToken > depositQueue) {
            _mint(_account, (_depositAmount.mul(totalSupply())).div(_balanceInUnderlyingToken.sub(depositQueue)));
        }
    }
}
