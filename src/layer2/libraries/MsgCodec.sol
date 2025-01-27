// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library MsgCodec {
    // Offset constants for decoding messages
    uint256 private constant MESSAGE_TYPE_OFFSET = 32;
    uint256 private constant COMPOSE_TYPE_OFFSET = 64;
    uint256 private constant COMPOSE_RECEIVER_OFFSET = 32;

    /**
     * @dev Retrieves the message type from the message.
     * @param _msg The message.
     * @return The message type.
     */
    function messageType(bytes calldata _msg) internal pure returns (uint8) {
        return abi.decode(_msg[:MESSAGE_TYPE_OFFSET], (uint8));
    }

    /**
     * @dev Retrieve the relavant parameters from the message.
     * @param _msg The message.
     * @return msgType The message type.
     * @return amount The amount.
     * @return assetsPerShare The assets per share.
     * @return receiver The token receiver.
     * @return syncedIds The synced IDs.
     */
    function decodeL1Msg(
        bytes calldata _msg
    )
        internal
        pure
        returns (
            uint8 msgType,
            uint256 amount,
            uint256 assetsPerShare,
            address receiver,
            bytes32[] memory syncedIds
        )
    {
        (, uint256 composeMsgLen) = isComposed(_msg);

        (msgType, amount, assetsPerShare, receiver, syncedIds) = abi.decode(
            _msg[COMPOSE_TYPE_OFFSET:_msg.length - composeMsgLen],
            (uint8, uint256, uint256, address, bytes32[])
        );
    }

    /**
     * @dev Retrieve the relavant parameters from the sync message.
     * @param _msg The message.
     * @return token The deposited token.
     * @return amountIn The amount in.
     * @return amountOut The amount out.
     */
    function decodeSync(
        bytes calldata _msg
    )
        internal
        pure
        returns (address token, uint256 amountIn, uint256 amountOut)
    {
        (token, amountIn, amountOut) = abi.decode(
            _msg[MESSAGE_TYPE_OFFSET:],
            (address, uint256, uint256)
        );
    }

    /**
     * @dev Retrieve the relavant parameters from the withdraw message.
     * @param _msg The message.
     * @return amount The amount.
     * @return receiver The receiver address.
     */
    function decodeWithdraw(
        bytes calldata _msg
    ) internal pure returns (uint256 amount, address receiver) {
        (amount, receiver) = abi.decode(
            _msg[MESSAGE_TYPE_OFFSET:],
            (uint256, address)
        );
    }

    /**
     * @dev Retrieve the compose message.
     * @param _payload The LayerZero msg payload.
     * @return The compose message.
     */
    function composeMsg(
        bytes calldata _payload
    ) internal pure returns (bytes memory) {
        (bool composed, uint256 composeMsgLen) = isComposed(_payload);
        uint256 payloadLen = _payload.length;

        return composed ? 
            _payload[COMPOSE_RECEIVER_OFFSET + payloadLen - composeMsgLen:]
            : new bytes(0);
    }

    /**
     * @dev Check if the message is composed.
     * @param _payload The LayerZero msg payload.
     * @return Boolean if paylaod is composed and the length of the compose message.
     */
    function isComposed(
        bytes calldata _payload
    ) internal pure returns (bool, uint256) {
        (bool isCompose, uint256 composeMsgLen) = abi.decode(
            _payload[:COMPOSE_TYPE_OFFSET],
            (bool, uint256)
        );

        return (isCompose, composeMsgLen);
    }

    /**
     * @dev Encode the message.
     * @param _msg The message.
     * @param _composeMsg The compose message.
     * @return The encoded message.
     */
    function encode(
        bytes memory _msg,
        bytes memory _composeMsg
    ) internal pure returns (bytes memory) {
        uint256 composeMsgLen = _composeMsg.length;
        bool isCompose = composeMsgLen != 0;

        return
            abi.encodePacked(
                abi.encode(isCompose, composeMsgLen),
                _msg,
                _composeMsg
            );
    }

    /**
     * @dev Encode the compose message receiver.
     * The compose message must reserve its first 32 bytes for the receiver.
     * @param _payload The LayerZero msg payload.
     * @return The receiver address.
     */
    function composeTo(
        bytes calldata _payload
    ) internal pure returns (address) {
        (, uint256 composeMsgLen) = isComposed(_payload);
        uint256 payloadLen = _payload.length;
        uint256 start = payloadLen - composeMsgLen;
        uint256 end = start + 32;

        return address(uint160(uint256(bytes32(_payload[start:end]))));
    }
}
