// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MessagingFee} from "src/vendor/layerzero/oft/interfaces/IOFT.sol";

interface IBridgeAdapter {
    function sendMessage(
        address _target,
        address _l2token,
        address _sender,
        bytes memory _message,
        uint32 _minGasLimit
    ) external payable;

    function quoteSend(
        uint32 _dstEid,
        address _receiver,
        address _tokenIn,
        uint256 _amountIn,
        uint256 _amountOut
    ) external view returns (uint256, MessagingFee memory);

    function withdrawRefund() external;
}
