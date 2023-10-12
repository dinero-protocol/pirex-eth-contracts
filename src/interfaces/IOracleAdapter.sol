// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IOracleAdapter {
    /**
        @notice Request voluntary exit
        @param  _pubKey  bytes  Key
     */
    function requestVoluntaryExit(
        bytes calldata _pubKey
    ) external;
}
