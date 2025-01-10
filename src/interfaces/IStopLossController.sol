// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStopLossController {
    event TradeExecuted(address indexed asset, uint256 amountIn, uint256 amountOut, Action action);
    event AssetThresholdSet(address indexed asset, int256 upperThreshold, int256 lowerThreshold);
    event TrapConfigSet(address indexed trapConfig);
    event WithdrawToken(address indexed token, address indexed to, uint256 amount);

    error OnlyTrapConfig();
    error InputArraysMustHaveSameLength();

    struct AssetConfig {
        address tokenIn;
        address tokenOut;
        uint24 poolFee;
        uint256 currentPrice;
        int256 upperThreshold;
        int256 lowerThreshold;
        uint256 swapAmount;
        uint256 slippageTolerance;
    }

    struct Trade {
        Action action;
        uint40 timestamp;
        uint256 originalPrice;
        uint256 triggerPrice;
    }

    enum Action {
        BUY,
        SELL,
        NONE
    }

    function getAssetConfig(address _asset) external view returns (AssetConfig memory);
    function getAssetPools() external view returns (address[] memory);
}
