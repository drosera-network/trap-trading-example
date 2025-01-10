// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract MockSwapRouter {
    function exactInputSingle(ISwapRouter.ExactInputSingleParams memory params) external payable returns (uint256) {
        return params.amountIn;
    }
}
