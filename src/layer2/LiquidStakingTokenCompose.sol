// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {LiquidStakingToken} from "src/layer2/LiquidStakingToken.sol";
import {Origin} from "src/vendor/layerzero-upgradeable/oapp/interfaces/IOAppReceiver.sol";
import {OFTComposeMsgCodec} from "src/vendor/layerzero/oft/libs/OFTComposeMsgCodec.sol";
import {MsgCodec} from "src/layer2/libraries/MsgCodec.sol";

/**
 * @title  LiquidStakingTokenCompose
 * @notice An DineroERC20Rebase OApp contract for handling LST operations between L2 and mainnet.
 * @dev    This contract facilitates interactions between mainnet PirexEth contracts and the L2 system.
 * @author redactedcartel.finance
 */
abstract contract LiquidStakingTokenCompose is LiquidStakingToken {
    /**
     * @dev Library: MsgCodec - Provides encoding and decoding of messages.
     */
    using MsgCodec for bytes;

    /**
     * @notice Contract constructor to initialize LiquidStakingToken with necessary parameters and configurations.
     * @dev    This constructor sets up the LiquidStakingToken contract, configuring key parameters and initializing state variables.
     * @param  _endpoint   address  The address of the LOCAL LayerZero endpoint.
     * @param  _srcEid     uint32   The source endpoint ID.
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _endpoint,
        uint32 _srcEid
    ) LiquidStakingToken(_endpoint, _srcEid) {}

    /**
     * @notice Handler for processing layerzero messages from L2.
     * @dev    Only accept and handle the deposit and rebase  messages from mainnet, which mints and stakes LiquidStakingToken.
     * @dev    _origin   Origin   The origin information containing the source endpoint and sender address.
     * @dev    _guid     bytes32  The unique identifier for the received LayerZero message.
     * @param  _message  bytes    The payload of the received message.
     * @dev              address  The address of the executor for the received message.
     * @dev              bytes    Additional arbitrary data provided by the corresponding executor.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal virtual override nonReentrant {
        _acceptNonce(_origin.srcEid, _origin.sender, _origin.nonce);

        uint256 amountReceived = _handleMessageReceived(_guid, _message);

        (bool isComposed, ) = _message.isComposed();
        if (isComposed) {
            _sendCompose(
                _origin.srcEid,
                _origin.nonce,
                _guid,
                amountReceived,
                _message
            );
        }
    }

    /**
     * @dev Decode the received message.
     * @param _message bytes The message to decode.
     * @return messageType uint256 The message type.
     * @return amount uint256 The amount.
     * @return assetsPerShare uint256 The assets per share.
     * @return receiver address The receiver address.
     * @return syncedIds bytes32[] The synced IDs.
     */
    function _decodeReceivedMessage(
        bytes calldata _message
    )
        internal
        pure
        override
        returns (
            uint256 messageType,
            uint256 amount,
            uint256 assetsPerShare,
            address receiver,
            bytes32[] memory syncedIds
        )
    {
        return _message.decodeL1Msg();
    }

    /**
     * @dev Send compose message to the destination endpoint.
     * @param _srcEid endpoint ID of the source.
     * @param _nonce nonce of the message.
     * @param _guid GUID of the message.
     * @param _amountReceived amount received.
     * @param _message message to compose.
     */
    function _sendCompose(
        uint32 _srcEid,
        uint64 _nonce,
        bytes32 _guid,
        uint256 _amountReceived,
        bytes calldata _message
    ) internal virtual {
        // @dev composeMsg format for the OFT.
        bytes memory composeMsg = OFTComposeMsgCodec.encode(
            _nonce,
            _srcEid,
            _amountReceived,
            abi.encodePacked(
                OFTComposeMsgCodec.addressToBytes32(address(this)),
                _message.composeMsg()
            )
        );

        endpoint.sendCompose(
            _message.composeTo(),
            _guid,
            0 /* the index of the composed message*/,
            composeMsg
        );
    }
}
