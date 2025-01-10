# Drosera Stop Loss Trading System

## Overview

The Drosera Stop Loss example is an automated trading system that enables automated stop-loss execution for token pairs trading on Uniswap V3 pools. The system runs a Drosera trap which reacts to specific on-chain state. In our system, traps monitor price movements and automatically execute trades when certain conditions are met.

## Architecture

The system consists of two main components:

1. **StopLossController**: The core contract that manages asset configurations and executes trades on Uniswap V3 pools.
2. **StopLossTrap**: An off-chainmonitoring contract that watches for price movements and triggers trades when thresholds are crossed.

### How It Works

1. The system monitors Uniswap V3 pool prices for configured asset pairs
2. When price movements cross predefined thresholds:
   - Upper threshold breach → Triggers a sell order
   - Lower threshold breach → Triggers a buy order
3. Trades are automatically executed through the Uniswap V3 router with configurable slippage protection

## Features

- **Automated Stop Loss**: Set and forget stop-loss orders that execute automatically
- **Configurable Thresholds**: Set custom upper and lower price thresholds for each asset pair
- **Slippage Protection**: Built-in slippage tolerance settings for trade execution
- **Multi-Asset Support**: Monitor and manage multiple trading pairs simultaneously
- **Price Deviation Tracking**: Calculates and responds to percentage-based price movements
- **Pausable**: Emergency pause functionality for all trading activity

## Setup

### Prerequisites

- Bun installed
- Foundry development environment
- Access to an Ethereum node (local or remote) for running the Drosera operator locally

### Installation

Install contract dependencies:

```bash
bun install
```

### Configuration

1. Deploy the StopLossController script (add in Uniswap V3 Router address for your chain before deploying):

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url ${RPC_URL} --broadcast -vvvv
```

2. Set up your `drosera.toml` file with the newly deployed StopLossController address and other required parameters

3. Add the StopLossController address to your `StopLossTrap` contract

4. Start your Drosera operator and deploy your new trap:

5. Update your StopLossController with the new trap address and unpause the contract:

```solidity
controller.setTrapAddress(trapAddress);
controller.unpause();
```

6. Add an asset to trade with desired thresholds:

```solidity
AssetConfig memory config = AssetConfig({
    tokenIn: tokenAAddress,
    tokenOut: tokenBAddress,
    upperThreshold: 1100, // 10% up
    lowerThreshold: 900,  // 10% down
    currentPrice: initialPrice,
    swapAmount: amountToTrade,
    slippageTolerance: minimumAmountOut,
    poolFee: poolFeeAmount
});

controller.initAssetConfig(poolAddress, config);
```

7. Make gorillions of money

## Usage

### Setting Up Stop Loss Orders

1. Initialize asset configuration with desired thresholds:

```solidity
controller.initAssetConfig(poolAddress, assetConfig);
```

2. The trap will continuously monitor prices and execute trades when thresholds are crossed:

- If price increases above upperThreshold → Sells tokens
- If price decreases below lowerThreshold → Buys tokens

### Monitoring and Management

- Check current asset configuration:

```solidity
AssetConfig config = controller.getAssetConfig(assetAddress);
```

- View trade history:

```solidity
Trade[] history = controller.assetTradeHistory(assetAddress);
```

- Update thresholds:

```solidity
controller.setAssetThreshold(assetAddress, newUpper, newLower);
```

## How Traps Work

The trap system uses a two-phase execution model:

1. **Collection Phase** (`collect()`):

   - Gathers current price data for all configured assets
   - Checks if the controller is paused
   - Retrieves current thresholds and configurations

2. **Response Phase** (`shouldRespond()`):
   - Analyzes price movements against thresholds
   - Determines if trades should be executed
   - Prepares trade actions if thresholds are crossed

The system calculates price deviations using the formula:

```solidity
deviation = (current - previous) * 10_000 / previous
```

### Testing

Run the test suite:

```bash
forge test
```

### Deployment

1. Deploy the controller:

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url ${RPC_URL} --broadcast -vvvv
```
