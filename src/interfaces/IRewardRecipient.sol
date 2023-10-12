// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IRewardRecipient {
    /** 
        @notice Dissolve validator
        @param  _pubKey  bytes    Key
        @param  _amount  uint256  ETH amount
     */
    function dissolveValidator(
        bytes calldata _pubKey,
        uint256 _amount
    ) external;

    /** 
        @notice Slash validator
        @param  _pubKey          bytes                      Key
        @param  _removeIndex     uint256                    Validator public key index
        @param  _amount          uint256                    ETH amount
        @param  _unordered       bool                       Removed in gas efficient way or not
        @param  _burnerAccounts  DataTypes.BurnerAccount[]  Burner accounts
     */
    function slashValidator(
        bytes calldata _pubKey,
        uint256 _removeIndex,
        uint256 _amount,
        bool _unordered,
        DataTypes.BurnerAccount[] calldata _burnerAccounts
    ) external;
}
