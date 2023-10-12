// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IPirexEth {
    /**
        @notice Initiate redemption by burning pxETH in return for upxETH
        @param  _assets                     uint256  if caller is AutoPxEth then apxETH; pxETH otherwise
        @param  _receiver                   address  Receiver for upxETH
        @param  _shouldTriggerValidatorExit bool     Whether the initiation should trigger voluntary exit
        @return postFeeAmount               uint256  pxETH burnt for the receiver
        @return feeAmount                   uint256  pxETH distributed as fees
    */
    function initiateRedemption(
        uint256 _assets,
        address _receiver,
        bool _shouldTriggerValidatorExit
    ) external returns (uint256 postFeeAmount, uint256 feeAmount);

    /**
        @notice Dissolve validator
        @param  _pubKey  bytes  Key
     */
    function dissolveValidator(bytes calldata _pubKey) external payable;

    /**
        @notice Update validator state to be slashed
        @param  _pubKey         bytes                     Public key of the validator
        @param  _removeIndex    uint256                   Index of validator to be slashed
        @param  _amount         uint256                   ETH amount released from Beacon chain 
        @param  _unordered      bool                      Whether remove from staking validator queue in order or not
        @param  _useBuffer      bool                      whether to use buffer to compensate the loss
        @param  _burnerAccounts DataTypes.BurnerAccount[] Burner accounts  
     */
    function slashValidator(
        bytes calldata _pubKey,
        uint256 _removeIndex,
        uint256 _amount,
        bool _unordered,
        bool _useBuffer,
        DataTypes.BurnerAccount[] calldata _burnerAccounts
    ) external payable;

    /**
        @notice Harvest and mint staking rewards when available  
        @param  _endBlock  uint256  Block until which ETH rewards is computed
     */
    function harvest(uint256 _endBlock) external payable;
}
