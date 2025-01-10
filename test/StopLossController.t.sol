// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StopLossController} from "../src/StopLossController.sol";
import {IStopLossController} from "../src/interfaces/IStopLossController.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {MockSwapRouter} from "./mock/MockSwapRouter.sol";
import {MockTrapConfig} from "./mock/MockTrapConfig.sol";

contract StopLossControllerTest is Test {
    StopLossController public controller;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockSwapRouter public swapRouter;
    MockTrapConfig public trapConfig;
    address public owner;
    address public user;

    event AssetThresholdSet(address indexed asset, int256 upperThreshold, int256 lowerThreshold);
    event TrapConfigSet(address indexed newTrapConfig);
    event TradeExecuted(address indexed asset, uint256 amountIn, uint256 amountOut, StopLossController.Action action);
    event WithdrawToken(address indexed token, address indexed recipient, uint256 amount);

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");

        tokenA = new MockERC20();
        tokenB = new MockERC20();
        swapRouter = new MockSwapRouter();

        trapConfig = new MockTrapConfig(address(controller));
        controller = new StopLossController(address(swapRouter));
        controller.setTrapConfig(address(trapConfig));
        controller.unpause();

        // add tokens to controller
        tokenA.mint(address(controller), 100 ether);
        tokenB.mint(address(controller), 100 ether);
    }

    function test_InitialState() public view {
        assertEq(address(controller.swapRouter()), address(swapRouter));
        assertEq(controller.trapConfig(), address(trapConfig));
    }

    function test_InitAssetConfig() public {
        StopLossController.AssetConfig memory config = IStopLossController.AssetConfig({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            upperThreshold: 1100,
            lowerThreshold: 900,
            currentPrice: 1000,
            swapAmount: 1 ether,
            slippageTolerance: 95e18,
            poolFee: 3000
        });

        controller.initAssetConfig(address(tokenA), config);

        StopLossController.AssetConfig memory savedConfig = controller.getAssetConfig(address(tokenA));
        assertEq(savedConfig.tokenIn, address(tokenA));
        assertEq(savedConfig.tokenOut, address(tokenB));
        assertEq(savedConfig.upperThreshold, 1100);
        assertEq(savedConfig.lowerThreshold, 900);
    }

    function test_revert_InitAssetConfigZeroAddress() public {
        StopLossController.AssetConfig memory config = IStopLossController.AssetConfig({
            tokenIn: address(0),
            tokenOut: address(tokenB),
            upperThreshold: 1100,
            lowerThreshold: 900,
            currentPrice: 1000,
            swapAmount: 100e18,
            slippageTolerance: 95e18,
            poolFee: 3000
        });

        vm.expectRevert("Invalid token addresses");
        controller.initAssetConfig(address(tokenA), config);
    }

    function test_UpdateTrade() public {
        StopLossController.AssetConfig memory config = IStopLossController.AssetConfig({
            tokenIn: address(tokenA),
            tokenOut: address(tokenB),
            upperThreshold: 1100,
            lowerThreshold: 900,
            currentPrice: 1000,
            swapAmount: 100e18,
            slippageTolerance: 95e18,
            poolFee: 3000
        });

        address assetAddress = address(tokenA);
        controller.initAssetConfig(assetAddress, config);

        // update data
        uint8[] memory actions = new uint8[](1);
        actions[0] = uint8(IStopLossController.Action.SELL);

        uint256[] memory prices = new uint256[](1);
        prices[0] = 1200;

        address[] memory assets = new address[](1);
        assets[0] = assetAddress;

        vm.prank(address(trapConfig));
        controller.updateTrade(actions, prices, assets);

        // check if trade was recorded
        StopLossController.AssetConfig memory updatedConfig = controller.getAssetConfig(assetAddress);
        assertEq(updatedConfig.currentPrice, 1200);
    }

    function test_revert_UpdateTradeUnauthorized() public {
        uint8[] memory actions = new uint8[](1);
        uint256[] memory prices = new uint256[](1);
        address[] memory assets = new address[](1);

        vm.prank(user);
        vm.expectRevert(IStopLossController.OnlyTrapConfig.selector);
        controller.updateTrade(actions, prices, assets);
    }

    function test_SetAssetThreshold() public {
        address assetAddress = address(tokenA);
        int256 newUpperThreshold = 1500;
        int256 newLowerThreshold = 500;

        vm.expectEmit(true, true, true, true);
        emit AssetThresholdSet(assetAddress, newUpperThreshold, newLowerThreshold);

        controller.setAssetThreshold(assetAddress, newUpperThreshold, newLowerThreshold);

        (int256 upper, int256 lower) = controller.getThresholds(assetAddress);
        assertEq(upper, newUpperThreshold);
        assertEq(lower, newLowerThreshold);
    }

    function test_WithdrawToken() public {
        uint256 withdrawAmount = 1 ether;
        address recipient = makeAddr("recipient");

        vm.expectEmit(true, true, true, true);
        emit WithdrawToken(address(tokenA), recipient, withdrawAmount);

        controller.withdrawToken(address(tokenA), recipient, withdrawAmount);

        assertEq(tokenA.balanceOf(recipient), withdrawAmount);
    }

    function test_revert_WithdrawTokenInsufficientBalance() public {
        uint256 withdrawAmount = 1000 ether; // more than available
        address recipient = makeAddr("recipient");

        vm.expectRevert("Insufficient balance");
        controller.withdrawToken(address(tokenA), recipient, withdrawAmount);
    }

    receive() external payable {}
}
