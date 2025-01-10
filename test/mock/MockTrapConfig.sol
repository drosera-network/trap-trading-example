// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StopLossController} from "../../src/StopLossController.sol";

contract MockTrapConfig {
    StopLossController public controller;

    constructor(address _controller) {
        controller = StopLossController(_controller);
    }

    function triggerUpdate(uint8[] calldata _actions, uint256[] calldata _activePrices, address[] calldata _assets)
        external
    {
        controller.updateTrade(_actions, _activePrices, _assets);
    }
}
