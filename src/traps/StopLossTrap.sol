// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ITrap.sol";
import "../interfaces/IStopLossController.sol";
import {StopLossController, Pausable} from "../StopLossController.sol";

contract StopLossTrap is ITrap {
    address public stopLossController; // Add in StopLossController address here

    struct PriceData {
        bool paused;
        address poolAddress;
        uint256 setPrice;
        uint256 queryPrice;
        int256 upperThreshold;
        int256 lowerThreshold;
    }

    enum Action {
        BUY,
        SELL,
        NONE
    }

    constructor() {}

    function collect() external view returns (bytes memory) {
        IStopLossController controller = IStopLossController(stopLossController);
        address[] memory pools = controller.getAssetPools();

        PriceData[] memory data = new PriceData[](pools.length);

        for (uint256 i = 0; i < pools.length; i++) {
            StopLossController.AssetConfig memory assetConfig = controller.getAssetConfig(pools[i]);
            uint256 setPrice = assetConfig.currentPrice;
            uint256 queryPrice = _getPrice(pools[i]);
            PriceData memory poolData = PriceData({
                paused: Pausable(address(controller)).paused(),
                poolAddress: pools[i],
                setPrice: setPrice,
                queryPrice: queryPrice,
                upperThreshold: assetConfig.upperThreshold,
                lowerThreshold: assetConfig.lowerThreshold
            });
            data[i] = poolData;
        }

        return abi.encode(data);
    }

    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        PriceData[] memory currentPrices = abi.decode(data[0], (PriceData[]));
        uint8[] memory actions = new uint8[](currentPrices.length);
        uint256[] memory prices = new uint256[](currentPrices.length);
        address[] memory assets = new address[](currentPrices.length);
        bool hasAction = false;

        for (uint256 i = 0; i < currentPrices.length; i++) {
            PriceData memory assetData = currentPrices[i];
            // check if controller is paused
            if (assetData.paused) {
                return (false, bytes(""));
            }

            int256 deviation = _calculateDeviation(assetData.queryPrice, assetData.setPrice);

            if (deviation >= currentPrices[i].upperThreshold) {
                // price pumping, sell
                actions[i] = uint8(Action.SELL);
                prices[i] = assetData.queryPrice;
                assets[i] = assetData.poolAddress;
            } else if (deviation <= currentPrices[i].lowerThreshold) {
                // price crashing, buy
                actions[i] = uint8(Action.BUY);
                prices[i] = assetData.queryPrice;
                assets[i] = assetData.poolAddress;
            } else {
                actions[i] = uint8(Action.NONE);
                prices[i] = 0;
                assets[i] = address(0);
            }
        }

        if (hasAction) {
            return (true, abi.encode(actions, prices, assets));
        }

        return (false, bytes(""));
    }

    function _getPrice(address _poolAddress) internal view returns (uint256) {
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(_poolAddress).slot0();
        uint256 sqrtPrice = uint256(sqrtPriceX96);

        uint256 SCALE = 1e18;
        uint256 price = ((sqrtPrice * sqrtPrice * SCALE) >> 192); // need to bitshift for scale

        return price;
    }

    function _calculateDeviation(uint256 current, uint256 previous) internal pure returns (int256) {
        if (current == previous) {
            return 0;
        }

        int256 difference = int256(current) - int256(previous);
        return (difference * 10_000) / int256(previous);
    }
}

interface IUniswapV3Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}
