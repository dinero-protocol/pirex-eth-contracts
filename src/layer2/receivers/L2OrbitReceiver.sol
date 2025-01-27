// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseMessengerUpgradeable} from "src/vendor/layerzero/syncpools/utils/BaseMessengerUpgradeable.sol";
import {OAppReceiverUpgradeable, OAppCoreUpgradeable, Origin} from "src/vendor/layerzero-upgradeable/oapp/OAppReceiverUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {IArbitrumMessenger} from "../interfaces/IArbitrumMessenger.sol";
import {IL1Receiver} from "src/vendor/layerzero/syncpools/interfaces/IL1Receiver.sol";
import {Errors} from "../libraries/Errors.sol";
import {IWETH} from "../interfaces/IWETH.sol";

/**
 * @title L2 Orbit Receiver
 * @notice L2 receiver contract from Orbit chains
 * @dev This contract receives messages from the Orbit based L3 messenger and forwards them to the L2 Arbitrum receiver
 * It only supports ETH
 */
contract L2OrbitReceiver is
    BaseMessengerUpgradeable,
    OAppReceiverUpgradeable,
    ReentrancyGuardUpgradeable
{
    /**
     * @notice The endpoint ID for L1.
     * @dev This constant defines the source endpoint ID for the L1.
     */
    uint32 internal immutable L1_EID;

    IWETH internal immutable WETH;

    struct OrbitReceiverStorage {
        /**
         * @notice The processed nonce.
         * @dev The nonce of the last processed message.
         */
        uint64 processedNonce;
        /**
         * @notice The received messages.
         * @dev Mapping to track the received messages.
         */
        mapping(uint64 nonce => bytes data) msgReceived;
        /**
         * @notice The nonce for the received messages.
         * @dev Mapping to track the maximum received nonce for each source endpoint and sender
         */
        mapping(uint32 eid => mapping(bytes32 sender => uint64 nonce)) receivedNonce;
    }

    // keccak256(abi.encode(uint256(keccak256(orbitreceiver.storage.l2receiver)) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant OrbitReceiverStorageLocation =
        0xc48c16b68c0600532de01c73080a048234d6cbdabfffc5a7134ccc1ba5987300;

    function _getOrbitReceiverStorage()
        internal
        pure
        returns (OrbitReceiverStorage storage $)
    {
        assembly {
            $.slot := OrbitReceiverStorageLocation
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address _endpoint,
        address _weth,
        uint32 _l1Eid
    ) OAppCoreUpgradeable(_endpoint) {
        L1_EID = _l1Eid;
        WETH = IWETH(_weth);
        _disableInitializers();
    }

    /**
     * @dev Initializer for L2 Orbit Receiver ETH
     * @param messenger Address of the messenger contract
     * @param owner Address of the owner
     */
    function initialize(address messenger, address owner) external initializer {
        __Ownable_init(owner);
        __BaseMessenger_init(messenger);
    }

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
        bytes32,
        bytes calldata _message,
        address,
        bytes calldata
    ) internal override nonReentrant {
        uint64 nonce = _acceptNonce(
            _origin.srcEid,
            _origin.sender,
            _origin.nonce
        );

        OrbitReceiverStorage storage $ = _getOrbitReceiverStorage();

        $.msgReceived[nonce] = _message;
    }

    /**
     * @dev Function to receive messages from the L2 messenger
     */
    function sendTxToL1() external {
        OrbitReceiverStorage storage $ = _getOrbitReceiverStorage();

        uint64 nonce = ++$.processedNonce;
        bytes memory message = $.msgReceived[nonce];

        if (message.length == 0) revert Errors.InvalidNonce();

        (, , , uint256 amountIn, ) = abi.decode(
            message,
            (uint32, bytes32, address, uint256, uint256)
        );

        WETH.withdraw(amountIn);

        bytes memory data = abi.encodeCall(
            IL1Receiver.onMessageReceived,
            message
        );

        IArbitrumMessenger(getMessenger()).sendTxToL1{value: amountIn}(
            address(uint160(uint256(peers(L1_EID)))),
            data
        );
    }

    /**
     * @dev Internal function to accept nonce from the specified source endpoint and sender.
     * @param _srcEid Source endpoint ID.
     * @param _sender Sender's address in bytes32 format.
     * @param _nonce The nonce to be accepted.
     */
    function _acceptNonce(
        uint32 _srcEid,
        bytes32 _sender,
        uint64 _nonce
    ) internal returns (uint64) {
        OrbitReceiverStorage storage $ = _getOrbitReceiverStorage();

        if (_nonce != $.receivedNonce[_srcEid][_sender] + 1)
            revert Errors.InvalidNonce();

        return $.receivedNonce[_srcEid][_sender] += 1;
    }

    receive() external payable {}
}
