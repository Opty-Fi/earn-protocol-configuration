// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

//  libraries
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { DataTypes } from "./libraries/types/DataTypes.sol";

//  helper contracts
import { ModifiersController } from "./ModifiersController.sol";
import { RegistryProxy } from "./RegistryProxy.sol";

//  interfaces
import { IVault } from "./interfaces/opty/IVault.sol";
import { IRegistryV2 } from "./interfaces/opty/IRegistryV2.sol";
import { Constants } from "./utils/Constants.sol";

/**
 * @title Registry Contract
 * @author Opty.fi
 * @dev Contract to persit status of tokens,lpTokens,lp/cp and Vaults
 */
contract RegistryV2 is IRegistryV2, ModifiersController {
    using Address for address;
    using SafeMath for uint256;

    /**
     * @dev Set RegistryProxy to act as Registry
     * @param _registryProxy RegistryProxy Contract address to act as Registry
     */
    function become(RegistryProxy _registryProxy) external {
        require(msg.sender == _registryProxy.governance(), "!governance");
        require(_registryProxy.acceptImplementation() == 0, "!unauthorized");
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function setTreasury(address _treasury) external override onlyGovernance {
        require(_treasury != address(0), "!address(0)");
        treasury = _treasury;
        emit TransferTreasury(treasury, msg.sender);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function setStrategyProvider(address _strategyProvider) external override onlyOperator {
        require(_strategyProvider.isContract(), "!isContract");
        strategyProvider = _strategyProvider;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function setRiskManager(address _riskManager) external override onlyOperator {
        require(_riskManager.isContract(), "!isContract");
        riskManager = _riskManager;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function setHarvestCodeProvider(address _harvestCodeProvider) external override onlyOperator {
        require(_harvestCodeProvider.isContract(), "!isContract");
        harvestCodeProvider = _harvestCodeProvider;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function setOPTY(address _opty) external override onlyOperator {
        require(_opty.isContract(), "!isContract");
        opty = _opty;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function setODEFIVaultBooster(address _odefiVaultBooster) external override onlyOperator {
        require(_odefiVaultBooster.isContract(), "!isContract");
        odefiVaultBooster = _odefiVaultBooster;
    }

    ///@TODO Add staking pool contract addresses

    /**
     * @inheritdoc IRegistryV2
     */
    function approveToken(address[] memory _tokens) external override onlyOperator {
        for (uint256 _i = 0; _i < _tokens.length; _i++) {
            _approveToken(_tokens[_i]);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function approveToken(address _token) external override onlyOperator {
        _approveToken(_token);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function revokeToken(address[] memory _tokens) external override onlyOperator {
        for (uint256 _i = 0; _i < _tokens.length; _i++) {
            _revokeToken(_tokens[_i]);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function revokeToken(address _token) external override onlyOperator {
        _revokeToken(_token);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function approveLiquidityPool(address[] memory _pools) external override onlyOperator {
        for (uint256 _i = 0; _i < _pools.length; _i++) {
            _approveLiquidityPool(_pools[_i]);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function approveLiquidityPool(address _pool) external override onlyOperator {
        _approveLiquidityPool(_pool);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function revokeLiquidityPool(address[] memory _pools) external override onlyOperator {
        for (uint256 _i = 0; _i < _pools.length; _i++) {
            _revokeLiquidityPool(_pools[_i]);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function revokeLiquidityPool(address _pool) external override onlyOperator {
        _revokeLiquidityPool(_pool);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function rateLiquidityPool(DataTypes.PoolRate[] memory _poolRates) external override onlyRiskOperator {
        for (uint256 _i = 0; _i < _poolRates.length; _i++) {
            _rateLiquidityPool(_poolRates[_i].pool, _poolRates[_i].rate);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function rateLiquidityPool(address _pool, uint8 _rate) external override onlyRiskOperator {
        _rateLiquidityPool(_pool, _rate);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function approveLiquidityPoolAndMapToAdapter(DataTypes.PoolAdapter[] memory _poolAdapters)
        external
        override
        onlyOperator
    {
        for (uint256 _i = 0; _i < _poolAdapters.length; _i++) {
            _approveLiquidityPool(_poolAdapters[_i].pool);
            _setLiquidityPoolToAdapter(_poolAdapters[_i].pool, _poolAdapters[_i].adapter);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function approveLiquidityPoolAndMapToAdapter(address _pool, address _adapter) external override onlyOperator {
        _approveLiquidityPool(_pool);
        _setLiquidityPoolToAdapter(_pool, _adapter);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function approveCreditPool(address[] memory _pools) external override onlyOperator {
        for (uint256 _i = 0; _i < _pools.length; _i++) {
            _approveCreditPool(_pools[_i]);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function approveCreditPool(address _pool) external override onlyOperator {
        _approveCreditPool(_pool);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function revokeCreditPool(address[] memory _pools) external override onlyOperator {
        for (uint256 _i = 0; _i < _pools.length; _i++) {
            _revokeCreditPool(_pools[_i]);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function revokeCreditPool(address _pool) external override onlyOperator {
        _revokeCreditPool(_pool);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function rateCreditPool(DataTypes.PoolRate[] memory _poolRates) external override onlyRiskOperator {
        for (uint256 _i = 0; _i < _poolRates.length; _i++) {
            _rateCreditPool(_poolRates[_i].pool, _poolRates[_i].rate);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function rateCreditPool(address _pool, uint8 _rate) external override onlyRiskOperator {
        _rateCreditPool(_pool, _rate);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function setLiquidityPoolToAdapter(DataTypes.PoolAdapter[] memory _poolAdapters) external override onlyOperator {
        for (uint256 _i = 0; _i < _poolAdapters.length; _i++) {
            require(_poolAdapters[_i].adapter.isContract(), "!_adapter.isContract()");
            require(
                liquidityPools[_poolAdapters[_i].pool].isLiquidityPool ||
                    creditPools[_poolAdapters[_i].pool].isLiquidityPool,
                "!liquidityPools"
            );
            _setLiquidityPoolToAdapter(_poolAdapters[_i].pool, _poolAdapters[_i].adapter);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function setLiquidityPoolToAdapter(address _pool, address _adapter) external override onlyOperator {
        require(_adapter.isContract(), "!_adapter.isContract()");
        require(liquidityPools[_pool].isLiquidityPool || creditPools[_pool].isLiquidityPool, "!liquidityPools");
        _setLiquidityPoolToAdapter(_pool, _adapter);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function approveTokenAndMapToTokensHash(DataTypes.TokensHashDetail[] memory _tokensHashesDetails)
        external
        override
        onlyOperator
    {
        for (uint256 _i = 0; _i < _tokensHashesDetails.length; _i++) {
            for (uint256 _j = 0; _j < _tokensHashesDetails[_i].tokens.length; _j++) {
                _approveToken(_tokensHashesDetails[_i].tokens[_j]);
            }
            _setTokensHashToTokens(_tokensHashesDetails[_i].tokensHash, _tokensHashesDetails[_i].tokens);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function approveTokenAndMapToTokensHash(bytes32 _tokensHash, address[] memory _tokens)
        external
        override
        onlyOperator
    {
        for (uint256 _i = 0; _i < _tokens.length; _i++) {
            _approveToken(_tokens[_i]);
        }
        _setTokensHashToTokens(_tokensHash, _tokens);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function setTokensHashToTokens(DataTypes.TokensHashDetail[] memory _tokensHashesDetails)
        external
        override
        onlyOperator
    {
        for (uint256 _i = 0; _i < _tokensHashesDetails.length; _i++) {
            require(_areTokensApproved(_tokensHashesDetails[_i].tokens), "!tokens");
            _setTokensHashToTokens(_tokensHashesDetails[_i].tokensHash, _tokensHashesDetails[_i].tokens);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function setTokensHashToTokens(bytes32 _tokensHash, address[] memory _tokens) external override onlyOperator {
        require(_areTokensApproved(_tokens), "!tokens");
        _setTokensHashToTokens(_tokensHash, _tokens);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function updateRiskProfileBorrow(uint256 _riskProfileCode, bool _canBorrow) external override onlyRiskOperator {
        _updateRiskProfileBorrow(_riskProfileCode, _canBorrow);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function addRiskProfile(
        uint256 _riskProfileCode,
        string memory _name,
        string memory _symbol,
        bool _canBorrow,
        DataTypes.PoolRatingsRange memory _poolRatingRange
    ) external override onlyRiskOperator {
        _addRiskProfile(_riskProfileCode, _name, _symbol, _canBorrow, _poolRatingRange);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function addRiskProfile(
        uint256[] memory _riskProfileCodes,
        string[] memory _names,
        string[] memory _symbols,
        bool[] memory _canBorrow,
        DataTypes.PoolRatingsRange[] memory _poolRatingRanges
    ) external override onlyRiskOperator {
        require(_riskProfileCodes.length > 0, "!length>0");
        require(_riskProfileCodes.length == _poolRatingRanges.length, "!RP_PoolRatingsLength");
        require(_riskProfileCodes.length == _canBorrow.length, "!RP_canBorrowLength");
        require(_riskProfileCodes.length == _names.length, "!RP_namesLength");
        require(_riskProfileCodes.length == _symbols.length, "!RP_symbolsLength");

        for (uint256 _i = 0; _i < _riskProfileCodes.length; _i++) {
            _addRiskProfile(_riskProfileCodes[_i], _names[_i], _symbols[_i], _canBorrow[_i], _poolRatingRanges[_i]);
        }
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function updateRPPoolRatings(uint256 _riskProfileCode, DataTypes.PoolRatingsRange memory _poolRatingRange)
        external
        override
        onlyRiskOperator
    {
        _updateRPPoolRatings(_riskProfileCode, _poolRatingRange);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function removeRiskProfile(uint256 _index) external override onlyRiskOperator {
        _removeRiskProfile(_index);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function resetV1Contracts() external override onlyFinanceOperator {
        investStrategyRegistry = address(0);
        aprOracle = address(0);
        strategyManager = address(0);
        optyStakingRateBalancer = address(0);
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getTokenHashes() public view override returns (bytes32[] memory) {
        return tokensHashIndexes;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getTokensHashToTokenList(bytes32 _tokensHash) public view override returns (address[] memory) {
        return tokensHashToTokens[_tokensHash].tokens;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getRiskProfileList() public view override returns (uint256[] memory) {
        return riskProfilesArray;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getVaultConfiguration(address _vault) public view override returns (DataTypes.VaultConfiguration memory) {
        return vaultToVaultConfiguration[_vault];
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getTokensHashIndexByHash(bytes32 _tokensHash) public view override returns (uint256) {
        return tokensHashToTokens[_tokensHash].index;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getTokensHashByIndex(uint256 _index) public view override returns (bytes32) {
        return tokensHashIndexes[_index];
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function isApprovedToken(address _token) public view override returns (bool) {
        return tokens[_token];
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getStrategyProvider() public view override returns (address) {
        return strategyProvider;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getRiskProfile(uint256 _riskProfileCode) public view override returns (DataTypes.RiskProfile memory) {
        return riskProfiles[_riskProfileCode];
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getRiskManager() public view override returns (address) {
        return riskManager;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getOPTYDistributor() public view override returns (address) {
        return optyDistributor;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getODEFIVaultBooster() external view override returns (address) {
        return odefiVaultBooster;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getGovernance() public view override returns (address) {
        return governance;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getFinanceOperator() public view override returns (address) {
        return financeOperator;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getRiskOperator() public view override returns (address) {
        return riskOperator;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getStrategyOperator() public view override returns (address) {
        return strategyOperator;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getOperator() public view override returns (address) {
        return operator;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getHarvestCodeProvider() public view override returns (address) {
        return harvestCodeProvider;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getLiquidityPool(address _pool) public view override returns (DataTypes.LiquidityPool memory) {
        return liquidityPools[_pool];
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getStrategyConfiguration()
        public
        view
        override
        returns (DataTypes.StrategyConfiguration memory _strategyConfiguration)
    {
        _strategyConfiguration.investStrategyRegistry = investStrategyRegistry;
        _strategyConfiguration.strategyProvider = strategyProvider;
        _strategyConfiguration.aprOracle = aprOracle;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getVaultStrategyConfiguration()
        public
        view
        override
        returns (DataTypes.VaultStrategyConfiguration memory _vaultStrategyConfiguration)
    {
        _vaultStrategyConfiguration.strategyManager = strategyManager;
        _vaultStrategyConfiguration.riskManager = riskManager;
        _vaultStrategyConfiguration.optyDistributor = optyDistributor;
        _vaultStrategyConfiguration.odefiVaultBooster = odefiVaultBooster;
        _vaultStrategyConfiguration.operator = operator;
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getLiquidityPoolToAdapter(address _pool) public view override returns (address) {
        return liquidityPoolToAdapter[_pool];
    }

    /**
     * @inheritdoc IRegistryV2
     */
    function getTreasuryShares(address _vault) public view override returns (DataTypes.TreasuryShare[] memory) {
        return vaultToVaultConfiguration[_vault].treasuryShares;
    }

    function _approveToken(address _token) internal {
        require(_token.isContract(), "!isContract");
        require(!tokens[_token], "!tokens");
        tokens[_token] = true;
        emit LogToken(_token, tokens[_token], msg.sender);
    }

    function _revokeToken(address _token) internal {
        require(tokens[_token], "!tokens");
        tokens[_token] = false;
        emit LogToken(_token, tokens[_token], msg.sender);
    }

    function _approveLiquidityPool(address _pool) internal {
        require(_pool.isContract(), "!isContract");
        require(!liquidityPools[_pool].isLiquidityPool, "!liquidityPools");
        liquidityPools[_pool].isLiquidityPool = true;
        emit LogLiquidityPool(_pool, liquidityPools[_pool].isLiquidityPool, msg.sender);
    }

    function _revokeLiquidityPool(address _pool) internal {
        require(liquidityPools[_pool].isLiquidityPool, "!liquidityPools");
        liquidityPools[_pool].isLiquidityPool = false;
        emit LogLiquidityPool(_pool, liquidityPools[_pool].isLiquidityPool, msg.sender);
    }

    function _rateLiquidityPool(address _pool, uint8 _rate) internal {
        require(liquidityPools[_pool].isLiquidityPool, "!liquidityPools");
        liquidityPools[_pool].rating = _rate;
        emit LogRateLiquidityPool(_pool, liquidityPools[_pool].rating, msg.sender);
    }

    function _approveCreditPool(address _pool) internal {
        require(_pool.isContract(), "!isContract");
        require(!creditPools[_pool].isLiquidityPool, "!creditPools");
        creditPools[_pool].isLiquidityPool = true;
        emit LogCreditPool(_pool, creditPools[_pool].isLiquidityPool, msg.sender);
    }

    function _revokeCreditPool(address _pool) internal {
        require(creditPools[_pool].isLiquidityPool, "!creditPools");
        creditPools[_pool].isLiquidityPool = false;
        emit LogCreditPool(_pool, creditPools[_pool].isLiquidityPool, msg.sender);
    }

    function _rateCreditPool(address _pool, uint8 _rate) internal {
        require(creditPools[_pool].isLiquidityPool, "!liquidityPools");
        creditPools[_pool].rating = _rate;
        emit LogRateCreditPool(_pool, creditPools[_pool].rating, msg.sender);
    }

    function _setLiquidityPoolToAdapter(address _pool, address _adapter) internal {
        liquidityPoolToAdapter[_pool] = _adapter;
        emit LogLiquidityPoolToAdapter(_pool, _adapter, msg.sender);
    }

    function _setTokensHashToTokens(bytes32 _tokensHash, address[] memory _tokens) internal {
        require(_isNewTokensHash(_tokensHash), "!_isNewTokensHash");
        tokensHashIndexes.push(_tokensHash);
        tokensHashToTokens[_tokensHash].index = tokensHashIndexes.length - 1;
        tokensHashToTokens[_tokensHash].tokens = _tokens;
        emit LogTokensToTokensHash(_tokensHash, msg.sender);
    }

    function _addRiskProfile(
        uint256 _riskProfileCode,
        string memory _name,
        string memory _symbol,
        bool _canBorrow,
        DataTypes.PoolRatingsRange memory _poolRatingRange
    ) internal {
        require(!riskProfiles[_riskProfileCode].exists, "RP_already_exists");
        require(bytes(_name).length > 0, "RP_name_empty");
        require(bytes(_symbol).length > 0, "RP_symbol_empty");
        riskProfilesArray.push(_riskProfileCode);
        riskProfiles[_riskProfileCode].name = _name;
        riskProfiles[_riskProfileCode].symbol = _symbol;
        riskProfiles[_riskProfileCode].canBorrow = _canBorrow;
        riskProfiles[_riskProfileCode].poolRatingsRange.lowerLimit = _poolRatingRange.lowerLimit;
        riskProfiles[_riskProfileCode].poolRatingsRange.upperLimit = _poolRatingRange.upperLimit;
        riskProfiles[_riskProfileCode].index = riskProfilesArray.length - 1;
        riskProfiles[_riskProfileCode].exists = true;

        emit LogRiskProfile(
            riskProfiles[_riskProfileCode].index,
            riskProfiles[_riskProfileCode].exists,
            riskProfiles[_riskProfileCode].canBorrow,
            msg.sender
        );
        emit LogRPPoolRatings(
            riskProfiles[_riskProfileCode].index,
            riskProfiles[_riskProfileCode].poolRatingsRange.lowerLimit,
            riskProfiles[_riskProfileCode].poolRatingsRange.upperLimit,
            msg.sender
        );
    }

    function _updateRiskProfileBorrow(uint256 _riskProfileCode, bool _canBorrow) internal {
        require(riskProfiles[_riskProfileCode].exists, "!Rp_Exists");
        riskProfiles[_riskProfileCode].canBorrow = _canBorrow;
        emit LogRiskProfile(
            riskProfiles[_riskProfileCode].index,
            riskProfiles[_riskProfileCode].exists,
            riskProfiles[_riskProfileCode].canBorrow,
            msg.sender
        );
    }

    function _updateRPPoolRatings(uint256 _riskProfileCode, DataTypes.PoolRatingsRange memory _poolRatingRange)
        internal
    {
        require(riskProfiles[_riskProfileCode].exists, "!Rp_Exists");
        riskProfiles[_riskProfileCode].poolRatingsRange.lowerLimit = _poolRatingRange.lowerLimit;
        riskProfiles[_riskProfileCode].poolRatingsRange.upperLimit = _poolRatingRange.upperLimit;
        emit LogRPPoolRatings(
            riskProfiles[_riskProfileCode].index,
            riskProfiles[_riskProfileCode].poolRatingsRange.lowerLimit,
            riskProfiles[_riskProfileCode].poolRatingsRange.upperLimit,
            msg.sender
        );
    }

    function _removeRiskProfile(uint256 _index) internal {
        require(_index <= riskProfilesArray.length, "Invalid_Rp_index");
        uint256 _riskProfileCode = riskProfilesArray[_index];
        require(riskProfiles[_riskProfileCode].exists, "!Rp_Exists");
        riskProfiles[_riskProfileCode].exists = false;
        emit LogRiskProfile(
            _index,
            riskProfiles[_riskProfileCode].exists,
            riskProfiles[_riskProfileCode].canBorrow,
            msg.sender
        );
    }

    /**
     * @dev Checks duplicate tokensHash
     * @param _hash Hash of the token address/addresses
     * @return A boolean value indicating whether duplicate _hash exists or not
     */
    function _isNewTokensHash(bytes32 _hash) internal view returns (bool) {
        if (tokensHashIndexes.length == 0) {
            return true;
        }
        return (tokensHashIndexes[tokensHashToTokens[_hash].index] != _hash);
    }

    /**
     * @dev Checks approved tokens
     * @param _tokens List of the token addresses
     */
    function _areTokensApproved(address[] memory _tokens) internal view returns (bool) {
        for (uint256 _i = 0; _i < _tokens.length; _i++) {
            if (!tokens[_tokens[_i]]) {
                return false;
            }
        }
        return true;
    }
}
