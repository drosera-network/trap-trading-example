// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {StopLossController} from "../src/StopLossController.sol";

contract DeployScript is Script {
    uint256 deployerPrivateKey;
    address swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564; // Polygon Uniswap V3 Swap Router

    function run() public {
        deployerPrivateKey = vm.envUint("DROSERA_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        StopLossController controller = new StopLossController(swapRouter);

        console.log("Controller deployed at:", address(controller));

        vm.stopBroadcast();
    }
}
