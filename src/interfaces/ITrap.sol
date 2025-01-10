// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITrap {
    // Data collection function
    function collect() external view returns (bytes memory);

    // Validation function
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory);
}
