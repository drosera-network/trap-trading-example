// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/utils/structs/EnumerableSet.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IStopLossController} from "./interfaces/IStopLossController.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/**
 * @title StopLossController
 * @dev Implements an automated stop-loss mechanism for trading assets using Uniswap V3 pools
 * The contract monitors asset prices and executes trades when predefined thresholds are reached
 */
contract StopLossController is IStopLossController, Ownable, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;

    ISwapRouter public swapRouter;

    address public trapConfig;

    mapping(address => AssetConfig) public assetConfigs;
    mapping(address => Trade[]) public assetTradeHistory;
    EnumerableSet.AddressSet private assetPools;

    modifier onlyTrapConfig() {
        if (msg.sender != trapConfig) {
            revert OnlyTrapConfig();
        }
        _;
    }

    /**
     * @notice Constructor for the StopLossController
     * @dev Initializes the contract with the given swap router. Contract is initially paused so we can set address in trap
     * Once deployed, set address in trap and then add trapConfig address to the contract and unpause
     * @param _swapRouter Address of the Uniswap V3 swap router
     */
    constructor(address _swapRouter) Ownable(msg.sender) {
        swapRouter = ISwapRouter(_swapRouter);
        // initially paused so we can set address in trap
        _pause();
    }

    /**
     * @notice Updates trades for multiple assets based on price movements
     * @dev Can only be called by the trapConfig address
     * @param _actions Array of actions to take for each asset (0 = Buy, 1 = Sell, 2 = None)
     * @param _activePrices Array of current prices for each asset
     * @param _assets Array of asset addresses to update
     * @custom:throws InputArraysMustHaveSameLength if input arrays have different lengths
     */
    function updateTrade(uint8[] calldata _actions, uint256[] calldata _activePrices, address[] calldata _assets)
        external
        onlyTrapConfig
    {
        if (_actions.length != _activePrices.length || _actions.length != _assets.length) {
            revert InputArraysMustHaveSameLength();
        }
        for (uint256 i = 0; i < _actions.length; i++) {
            if (Action(_actions[i]) == Action.NONE) {
                continue;
            }
            _updateTrade(Action(_actions[i]), _activePrices[i], _assets[i]);
            _swap(_assets[i], Action(_actions[i]));
        }
    }

    /**
     * @notice Retrieves the configuration for a specific asset
     * @param _asset The address of the asset
     * @return AssetConfig struct containing the asset's configuration
     */
    function getAssetConfig(address _asset) external view returns (AssetConfig memory) {
        return assetConfigs[_asset];
    }

    /**
     * @notice Returns all configured asset pool addresses
     * @return Array of asset pool addresses
     */
    function getAssetPools() external view returns (address[] memory) {
        return assetPools.values();
    }

    /**
     * @notice Gets the upper and lower threshold values for an asset
     * @param _asset The address of the asset
     * @return Upper threshold value
     * @return Lower threshold value
     */
    function getThresholds(address _asset) external view returns (int256, int256) {
        AssetConfig memory assetConfig = assetConfigs[_asset];
        return (assetConfig.upperThreshold, assetConfig.lowerThreshold);
    }

    /**
     * @notice Initializes configuration for a new asset
     * @dev Only callable by contract owner
     * @param _asset Address of the asset pool to configure
     * @param _config AssetConfig struct containing configuration parameters
     * @custom:requirements
     * - Asset address must not be zero address
     * - Token addresses in config must not be zero address
     * - Swap amount must be greater than 0
     * - Slippage tolerance must be greater than 0
     */
    function initAssetConfig(address _asset, AssetConfig memory _config) external onlyOwner {
        require(_asset != address(0), "Invalid asset address");
        require(_config.tokenIn != address(0) && _config.tokenOut != address(0), "Invalid token addresses");
        require(_config.swapAmount > 0, "Invalid swap amount");
        require(_config.slippageTolerance > 0, "Invalid slippage tolerance");

        assetPools.add(_asset);
        assetConfigs[_asset] = _config;
    }

    /**
     * @notice Sets new threshold values for an asset
     * @dev Only callable by contract owner
     * @param _asset The address of the asset
     * @param _upperThreshold New upper threshold value
     * @param _lowerThreshold New lower threshold value
     * @custom:emits AssetThresholdSet event
     */
    function setAssetThreshold(address _asset, int256 _upperThreshold, int256 _lowerThreshold) external onlyOwner {
        assetConfigs[_asset].upperThreshold = _upperThreshold;
        assetConfigs[_asset].lowerThreshold = _lowerThreshold;

        emit AssetThresholdSet(_asset, _upperThreshold, _lowerThreshold);
    }

    /**
     * @notice Updates the trap configuration address
     * @dev Only callable by contract owner
     * @param _trapConfig New trap configuration address
     * @custom:emits TrapConfigSet event
     */
    function setTrapConfig(address _trapConfig) external onlyOwner {
        trapConfig = _trapConfig;

        emit TrapConfigSet(_trapConfig);
    }

    /**
     * @notice Withdraws tokens from the contract
     * @dev Only callable by contract owner
     * @param _token Address of the token to withdraw
     * @param _to Recipient address
     * @param _amount Amount of tokens to withdraw
     * @custom:requirements
     * - Recipient address must not be zero address
     * - Amount must be greater than 0
     * - Contract must have sufficient balance
     * @custom:emits WithdrawToken event
     */
    function withdrawToken(address _token, address _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, "Invalid amount");
        require(IERC20(_token).balanceOf(address(this)) >= _amount, "Insufficient balance");

        IERC20(_token).transfer(_to, _amount);

        emit WithdrawToken(_token, _to, _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ------------ internal functions ------------------

    /**
     * @dev Internal function to update trade history and current price
     * @param _action Type of action being performed
     * @param _activePrice Current price of the asset
     * @param _asset Address of the asset
     */
    function _updateTrade(Action _action, uint256 _activePrice, address _asset) internal {
        Trade memory trade = Trade({
            action: _action,
            timestamp: uint40(block.timestamp),
            originalPrice: assetConfigs[_asset].currentPrice,
            triggerPrice: _activePrice
        });
        // update current price
        AssetConfig storage assetConfig = assetConfigs[_asset];
        assetConfig.currentPrice = _activePrice;

        // add trade to history
        assetTradeHistory[_asset].push(trade);
    }

    /**
     * @dev Internal function to execute a swap on Uniswap V3
     * @param _tokenAsset Address of the asset being traded
     * @param _action Type of action triggering the swap
     * @return Amount of tokens received from the swap
     * @custom:emits TradeExecuted event
     */
    function _swap(address _tokenAsset, Action _action) internal returns (uint256) {
        AssetConfig memory assetConfig = assetConfigs[_tokenAsset];
        IERC20(assetConfig.tokenIn).approve(address(swapRouter), assetConfig.swapAmount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: assetConfig.tokenIn,
            tokenOut: assetConfig.tokenOut,
            fee: assetConfig.poolFee,
            recipient: address(this),
            deadline: block.timestamp + 15,
            amountIn: assetConfig.swapAmount,
            amountOutMinimum: assetConfig.slippageTolerance,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = swapRouter.exactInputSingle(params);

        emit TradeExecuted(_tokenAsset, assetConfig.swapAmount, amountOut, _action);

        return amountOut;
    }
}
