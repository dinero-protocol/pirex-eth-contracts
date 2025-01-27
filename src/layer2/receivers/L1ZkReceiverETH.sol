// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {L1BaseReceiverUpgradeable} from "src/vendor/layerzero/syncpools/L1/L1BaseReceiverUpgradeable.sol";
import {IZkSync, L2Message} from "src/layer2/interfaces/IZkSync.sol";
import {UnsafeBytes} from "src/vendor/zksync/UnsafeBytes.sol";
import {Constants} from "src/vendor/layerzero/syncpools/libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";

/**
 * @title L1 Zk Receiver ETH Pull
 * @notice L1 receiver contract for ETH
 * @dev This contract proves messages finalized by the ZkSync Era and forwards them to the L1 sync pool
 * It only supports ETH
 */
contract L1ZkReceiverETH is L1BaseReceiverUpgradeable {
    struct L1ZkReceiverStorage {
        IZkSync zksync;
        mapping(uint32 => mapping(uint256 => bool)) messageProcessed;
    }

    // keccak256(abi.encode(uint256(keccak256(l1zkreceiver.storage.l1syncpool)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant L1ZkReceiverStorageLocation =
        0x9afae95578550b808d6217e490b7904a535b217c6ef95448b843ae6f03c73900;

    function _getL1ZkReceiverStorage()
        internal
        pure
        returns (L1ZkReceiverStorage storage $)
    {
        assembly {
            $.slot := L1ZkReceiverStorageLocation
        }
    }

    error FailedToProveMessageInclusion();
    error InvalidFunctionSignature();
    error MessageAlreadyProcessed();
    error CallFailed();
    error OnlySelf();

    event FinalizeSync(
        uint32 indexed blockNumber,
        uint256 indexed index,
        bytes message
    );

    modifier onlySelf() {
        if (msg.sender != address(this)) revert OnlySelf();
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializer for L1 Optimism Receiver ETH
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
     * @dev Function to receive messages from the L2 messenger
     * @param message The message received from the L2 messenger
     */
    function onMessageReceived(
        bytes calldata message
    ) public payable virtual override onlySelf {
        (
            uint32 originEid,
            bytes32 guid,
            address tokenIn,
            uint256 amountIn,
            uint256 amountOut
        ) = abi.decode(message, (uint32, bytes32, address, uint256, uint256));

        if (tokenIn != Constants.ETH_ADDRESS) revert Errors.OnlyETH();

        _forwardToL1SyncPool(
            originEid,
            _getAuthorizedL2Address(originEid),
            guid,
            tokenIn,
            amountIn,
            amountOut,
            amountIn
        );
    }

    /**
     * @notice Set the ZkSync contract address
     * @param _zksync ZkSync contract address
     */
    function setZkSync(address _zksync) external onlyOwner {
        if (_zksync == address(0)) {
            revert Errors.ZeroAddress();
        }

        _getL1ZkReceiverStorage().zksync = IZkSync(_zksync);
    }

    /**
     * @notice Get the ZkSync contract address
     * @return ZkSync contract address
     */
    function zkSync() external view returns (IZkSync) {
        return _getL1ZkReceiverStorage().zksync;
    }

    /**
     * @notice Check if the message was processed
     * @param _blockNumber zkSync block number in which the message was sent
     * @param _index The position in the L2 logs Merkle tree of the L2Log that was sent with the message
     * @return True if the message was processed
     */
    function isMessageProcessed(
        uint32 _blockNumber,
        uint256 _index
    ) external view returns (bool) {
        return _getL1ZkReceiverStorage().messageProcessed[_blockNumber][_index];
    }

    /**
     * @notice Finalize the sync by proving the message inclusion
     * @param _originEid Origin endpoint ID
     * @param _blockNumber zkSync block number in which the message was sent
     * @param _txBlockIndex Message index in the block
     * @param _index The position in the L2 logs Merkle tree of the L2Log that was sent with the message
     * @param _sender The sender address of the message
     * @param _message The message that was sent from L2
     * @param _proof Merkle proof for inclusion of L2 log that was sent with the message
     */
    function finalizeSync(
        uint32 _originEid,
        uint32 _blockNumber,
        uint16 _txBlockIndex,
        uint256 _index,
        address _sender,
        bytes calldata _message,
        bytes32[] calldata _proof
    ) external {
        L1ZkReceiverStorage storage $ = _getL1ZkReceiverStorage();

        if ($.messageProcessed[_blockNumber][_index]) {
            revert MessageAlreadyProcessed();
        }

        _checkSignatureAndCaller(_sender, _originEid, _message);

        bool success = $.zksync.proveL2MessageInclusion(
            _blockNumber,
            _index,
            L2Message({
                sender: _sender,
                data: _message,
                txNumberInBlock: _txBlockIndex
            }),
            _proof
        );
        if (!success) {
            revert FailedToProveMessageInclusion();
        }

        (bool callSuccess, ) = address(this).call(_message[76:]);
        if (!callSuccess) {
            revert CallFailed();
        }

        emit FinalizeSync(_blockNumber, _index, _message);

        $.messageProcessed[_blockNumber][_index] = true;
    }

    /**
     * @dev Internal function to forward the message to the L1 sync pool
     * @param originEid Origin endpoint ID
     * @param guid Message GUID
     * @param tokenIn Token address
     * @param amountIn Amount of tokens
     * @param amountOut Amount of tokens
     * @param valueToL1SyncPool Value to send to the L1 sync pool
     */
    function _forwardToL1SyncPool(
        uint32 originEid,
        bytes32,
        bytes32 guid,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        uint256 valueToL1SyncPool
    ) internal override {
        L1BaseReceiverStorage storage $ = _getL1BaseReceiverStorage();
        $.l1SyncPool.onMessageReceived{value: valueToL1SyncPool}(
            originEid,
            guid,
            tokenIn,
            amountIn,
            amountOut
        );
    }

    function _checkSignatureAndCaller(
        address _sender,
        uint32 _originEid,
        bytes calldata _message
    ) internal view {
        if (_sender != getMessenger())
            revert L1BaseReceiver__UnauthorizedCaller();

        (uint32 functionSignature, ) = UnsafeBytes.readUint32(_message, 76);
        if (bytes4(functionSignature) != this.onMessageReceived.selector) {
            revert InvalidFunctionSignature();
        }

        (address originalCaller, ) = UnsafeBytes.readAddress(_message, 56);
        if (
            _getAuthorizedL2Address(_originEid) !=
            bytes32(uint256(uint160(originalCaller)))
        ) {
            revert L1BaseReceiver__UnauthorizedL2Sender();
        }
    }

    receive() external payable {}
}
