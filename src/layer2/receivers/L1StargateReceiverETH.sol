// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1BaseReceiverUpgradeable} from "src/vendor/layerzero/syncpools/L1/L1BaseReceiverUpgradeable.sol";
import {ICrossDomainMessenger} from "src/vendor/layerzero/syncpools/interfaces/ICrossDomainMessenger.sol";
import {OFTComposeMsgCodec} from "src/vendor/layerzero/oft/libs/OFTComposeMsgCodec.sol";
import {Constants} from "src/vendor/layerzero/syncpools/libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";

/**
 * @title L1 Stargate Receiver
 * @notice L1 receiver contract for stargate bridge transactions
 * @dev This contract receives WETH from the stargate bridge, unwraps and forwards them to the L1 sync pool
 * It only supports ETH
 */
contract L1StargateReceiverETH is L1BaseReceiverUpgradeable {
    using OFTComposeMsgCodec for bytes;

    struct L1StargateReceiverStorage {
        mapping(uint32 originEid => bytes32 peer) peers;
        mapping(address tokenIn => address pool) pools;
    }

    // keccak256(abi.encode(uint256(keccak256(l1stargatereceiver.storage.l1syncpool)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant L1StargateReceiverStorageLocation =
        0xa277230823aa52e8f2c2adf04f9293d9984bf17323d392c9c6970c02eb95f100;

    function _getStargateReceiverStorage()
        internal
        pure
        returns (L1StargateReceiverStorage storage $)
    {
        assembly {
            $.slot := L1StargateReceiverStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializer for L1 Mode Receiver ETH
     * @param l1SyncPool Address of the L1 sync pool
     * @param messenger Address of the messenger contract
     * @param owner Address of the owner
     */
    function initialize(
        address l1SyncPool,
        address messenger,
        address owner
    ) external initializer {
        __Ownable_init(owner);
        __L1BaseReceiver_init(l1SyncPool, messenger);
    }

    /**
     * @dev Function to set the peer address
     * @param _eid Origin endpoint ID
     * @param _peer Address of the l2 peer
     */
    function setPeer(uint32 _eid, address _peer) external onlyOwner {
        if (_peer == address(0)) revert Errors.ZeroAddress();
        _getStargateReceiverStorage().peers[_eid] = bytes32(
            uint256(uint160(_peer))
        );
    }

    /**
     * @dev Function to set the pool address
     * @param _tokenIn Address of the token
     * @param _pool Address of the pool
     */
    function setPool(address _tokenIn, address _pool) external onlyOwner {
        if (_pool == address(0)) revert Errors.ZeroAddress();
        _getStargateReceiverStorage().pools[_tokenIn] = _pool;
    }

    /**
     * @dev Function to get the peer address
     * @return The address of the l2 peer
     */
    function peer(uint32 eid) external view returns (bytes32) {
        return _getStargateReceiverStorage().peers[eid];
    }

    /**
     * @dev Function to get the pool address
     * @return The address of the pool
     */
    function pool(address tokenIn) external view returns (address) {
        return _getStargateReceiverStorage().pools[tokenIn];
    }

    /**
     * @dev Function to receive messages from the L2 messenger
     */
    function lzCompose(
        address _from,
        bytes32,
        bytes calldata _message,
        address,
        bytes calldata
    ) external payable {
        bytes memory _composeMessage = _message.composeMsg();
        bytes32 l2Sender = _message.composeFrom();

        (
            uint32 originEid,
            bytes32 guid,
            address tokenIn,
            uint256 amountIn,
            uint256 amountOut
        ) = abi.decode(
                _composeMessage,
                (uint32, bytes32, address, uint256, uint256)
            );

        if (_getStargateReceiverStorage().pools[tokenIn] != _from) {
            revert Errors.NotAllowed();
        }

        _forwardToL1SyncPool(
            originEid,
            l2Sender,
            guid,
            tokenIn,
            amountIn,
            amountOut,
            amountOut
        );
    }

    /**
     * @dev Internal function to get the authorized L2 address
     * @param originEid Origin endpoint ID
     * @return The authorized L2 address
     */
    function _getAuthorizedL2Address(
        uint32 originEid
    ) internal view override returns (bytes32) {
        return _getStargateReceiverStorage().peers[originEid];
    }

    function onMessageReceived(bytes calldata message) external payable {}

    receive() external payable {}
}
