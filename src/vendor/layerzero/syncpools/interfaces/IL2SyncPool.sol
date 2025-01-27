// SPDX-License-Identifier: LZBL-1.2
pragma solidity ^0.8.20;

import {IOAppCore} from "src/vendor/layerzero-upgradeable/oapp/interfaces/IOAppCore.sol";
import {MessagingFee} from "src/vendor/layerzero/protocol/interfaces/ILayerZeroEndpointV2.sol";

interface IL2SyncPool is IOAppCore {
    function deposit(address tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        payable
        returns (uint256 amountOut);

    function sync(address tokenIn, bytes calldata extraOptions, MessagingFee calldata fee)
        external
        payable
        returns (uint256 unsyncedAmountIn, uint256 unsyncedAmountOut);
}
